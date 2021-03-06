provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
}

data "aws_region" "current" {}

module "vpc" {
  source      = "../../modules/vpc-scenario-1"
  name_prefix = var.name
  region      = var.region
  cidr        = var.vpc_cidr
  azs         = [data.aws_availability_zones.available.names[0]]

  extra_tags = var.extra_tags

  public_subnet_cidrs = var.public_subnet_cidrs
}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

resource "aws_key_pair" "main" {
  key_name   = var.name
  public_key = file(var.ssh_pubkey)
}

module "web-sg" {
  source      = "../../modules/security-group-base"
  description = "For my-web-app instances in ${var.name}"
  name        = "${var.name}-web"
  vpc_id      = module.vpc.vpc_id
}

# shared security group, open egress (outbound from nodes)
module "web-open-egress-rule" {
  source            = "../../modules/open-egress-sg"
  security_group_id = module.web-sg.id
}

resource "aws_security_group_rule" "winrm" {
  type              = "ingress"
  from_port         = 5985
  to_port           = 5986
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.web-sg.id
}

resource "aws_security_group_rule" "rdp" {
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.web-sg.id
}

data "template_file" "init" {
  template = file("${path.module}/bootstrap.win.txt")

  vars = {
    admin_password = var.admin_password
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.windows.image_id
  key_name                    = aws_key_pair.main.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2-ssm-role-profile.name
  instance_type               = "t2.micro"
  availability_zone           = data.aws_availability_zones.available.names[0]
  subnet_id                   = module.vpc.public_subnet_ids[0]
  associate_public_ip_address = "true"

  vpc_security_group_ids = [
    module.web-sg.id
  ]

  tags = {
    Name = "${var.name}-web"
  }
  user_data = data.template_file.init.rendered
}

module "private-subnets" {
  source      = "../../modules/subnets"
  azs         = slice(data.aws_availability_zones.available.names, 1, 3)
  vpc_id      = module.vpc.vpc_id
  name_prefix = "${var.name}-private"
  cidr_blocks = var.private_subnet_cidrs
  public      = false
  extra_tags  = merge(var.extra_tags, var.private_subnet_extra_tags)
}

module "nat-gateway" {
  source             = "../../modules/nat-gateways"
  vpc_id             = module.vpc.vpc_id
  name_prefix        = var.name
  nat_count          = length(var.public_subnet_cidrs)
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.private-subnets.ids
  extra_tags         = merge(var.extra_tags, var.nat_gateway_extra_tags)
}

resource "aws_directory_service_directory" "main" {
  name     = local.domain
  password = var.active_directory_password
  size     = "Small"
  edition  = "Standard"
  type     = "MicrosoftAD"

  vpc_settings {
    vpc_id     = module.vpc.vpc_id
    subnet_ids = module.private-subnets.ids
  }
}

resource "aws_iam_role" "ec2-ssm-role" {
  name               = "${var.name}-ec2-ssm-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm-instance" {
  role       = aws_iam_role.ec2-ssm-role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm-ad" {
  role       = aws_iam_role.ec2-ssm-role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_instance_profile" "ec2-ssm-role-profile" {
  name = "ec2-ssm-role-profile"
  role = aws_iam_role.ec2-ssm-role.name
}


resource "aws_ssm_document" "ssm_document" {
  name          = "ssm_document_example.com"
  document_type = "Command"
  content       = <<DOC
{
    "schemaVersion": "1.0",
    "description": "Automatic Domain Join Configuration",
    "runtimeConfig": {
        "aws:domainJoin": {
            "properties": {
                "directoryId": "${aws_directory_service_directory.main.id}",
                "directoryName": "${local.domain}",
                "dnsIpAddresses": ${jsonencode(aws_directory_service_directory.main.dns_ip_addresses)}
            }
        }
    }
}
DOC
}

resource "aws_ssm_association" "associate_ssm" {
  name        = aws_ssm_document.ssm_document.name
  instance_id = aws_instance.web.id
}
