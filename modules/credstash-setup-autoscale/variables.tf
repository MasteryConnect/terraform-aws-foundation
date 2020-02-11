variable "create_kms_key" {
  default     = true
  description = "Should the Master key be created"
  type        = string
}

variable "kms_key_name" {
  default     = "credstash"
  description = "KMS Master Key Name."
  type        = string
}

variable "enable_key_rotation" {
  default     = false
  description = "Specifies whether key rotation is enabled"
  type        = string
}

variable "create_db_table" {
  default     = true
  description = "Should the DynamoDB table be created"
  type        = string
}

variable "db_table_name" {
  default     = "credential-store"
  description = "Name of the DynamoDB table where credentials will be stored"
  type        = string
}

variable "create_reader_policy" {
  default     = false
  description = "Should credstash Secret Reader IAM Policy be created."
  type        = string
}

variable "create_writer_policy" {
  default     = false
  description = "Should credstash Secret Writer IAM Policy be created."
  type        = string
}

variable "max_read_capacity" {
  default     = 5
  description = "Maximum read capacity for autoscailing credstash table"
  type        = number
}

variable "min_read_capacity" {
  default     = 2
  description = "Minimum read capacity for autoscailing credstash table"
  type        = number
}

variable "max_write_capacity" {
  default     = 5
  description = "Maximum read capacity for autoscailing credstash table"
  type        = number
}

variable "min_write_capacity" {
  default     = 2
  description = "Minimum read capacity for autoscailing credstash table"
  type        = number
}

variable "write_target_utilization" {
  default     = 80
  description = "the ratio of consumed capacity units to provisioned capacity units, expressed as a percentage"
  type        = number
}

variable "read_target_utilization" {
  default     = 80
  description = "the ratio of consumed capacity units to provisioned capacity units, expressed as a percentage"
  type        = number
}

variable "DynamoDBAutoScaleRoleARN" {
  default     = "arn:aws:iam::226989638317:role/aws-service-role/dynamodb.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
  description = "Application autoscaling role for dynamodb"
  type        = string
