/**
 * ## Credstash Setup
 *
 * Setup KMS Master Key and a DynamoDB Table for use with Credstash.
 *
 * By default, this module doesn't need any variables to be set manually, but can
 * be overridden if necessary. By doing so it is possible to create either key or
 * database table or both, as well as other customizations.
 *
 * **Resources created here cannot be deleted using terraform and have to be deleted
 * manually. This behavior is to prevent possibility of sensitive data loss.**
 *
 */

resource "aws_kms_key" "credstash-key" {
  count               = var.create_kms_key ? 1 : 0
  description         = "Master key used by credstash"
  enable_key_rotation = var.enable_key_rotation

  tags = {
    Name = var.kms_key_name
  }
}

resource "aws_kms_alias" "credstash-key" {
  count         = var.create_kms_key ? 1 : 0
  name          = "alias/${var.kms_key_name}"
  target_key_id = aws_kms_key.credstash-key[0].key_id
}

resource "aws_dynamodb_table" "credstash-db" {
  count          = var.create_db_table ? 1 : 0
  name           = var.db_table_name
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "name"
  range_key      = "version"

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "version"
    type = "S"
  }

  lifecycle {
    ignore_changes = [ read_capacity, write_capacity ]
  }
}

## Writer Policy

resource "aws_iam_policy" "writer-policy" {
  count  = var.create_writer_policy ? 1 : 0
  name   = "${var.db_table_name}-writer"
  policy = data.aws_iam_policy_document.writer-policy.json
}

## Reader Policy

resource "aws_iam_policy" "reader-policy" {
  count  = var.create_reader_policy ? 1 : 0
  name   = "${var.db_table_name}-reader"
  policy = data.aws_iam_policy_document.reader-policy.json
}

## Reader autoscaling target and policy
resource "aws_appautoscaling_target" "credstash-table-read-target" {
  max_capacity       = var.max_read_capacity
  min_capacity       = var.min_read_capacity
  resource_id        = "table/${aws_dynamodb_table.credstash-db[0].name}"
  role_arn           = data.aws_iam_role.DynamoDBAutoScaleRole.arn
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "credstash-table-read-policy" {
  name = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.credstash-table-read-target.resource_id}"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.credstash-table-read-target.resource_id
  scalable_dimension = aws_appautoscaling_target.credstash-table-read-target.scalable_dimension
  service_namespace = aws_appautoscaling_target.credstash-table-read-target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = var.read_target_utilization
  }
}

## Writer autoscaling target and policy
resource "aws_appautoscaling_target" "credstash-table-write-target" {
  max_capacity       = var.max_write_capacity
  min_capacity       = var.min_write_capacity
  resource_id        = "table/${aws_dynamodb_table.credstash-db[0].name}"
  role_arn           = data.aws_iam_role.DynamoDBAutoScaleRole.arn
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "credstash-table-write-policy" {
  name = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.credstash-table-write-target.resource_id}"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.credstash-table-write-target.resource_id
  scalable_dimension = aws_appautoscaling_target.credstash-table-write-target.scalable_dimension
  service_namespace = aws_appautoscaling_target.credstash-table-write-target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = var.write_target_utilization
  }
}
