

# Sharing log data with SecOps via Firehose

locals {

}

data "aws_secretsmanager_secret_version" "xsiam_network_secret" {
  secret_id = "${var.secret_version_arn}"
}

resource "aws_flow_log" "firehose" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  iam_role_arn             = var.vpc_flow_log_iam_role
  log_destination          = aws_kinesis_firehose_delivery_stream.firehose_stream.arn
  max_aggregation_interval = "60"
  traffic_type             = "ALL"
  log_destination_type     = "kinesis-data-firehose"
  vpc_id                   = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-${var.environment}-vpc-flow-log-firehose-${random_id.flow_logs.hex}"
    }
  )
}

resource "aws_kinesis_firehose_delivery_stream" "firehose_stream" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.

  name        = "${var.tags_prefix}-${var.environment}-xsiam-delivery-stream"
  destination = "http_endpoint"

  tags = try(var.tags_common, {})

  http_endpoint_configuration {
    url                = var.endpoint_url
    name               = "${var.tags_prefix}-${var.environment}-endpoint"
    access_key         = var.secret_string
    buffering_size     = 5
    buffering_interval = 300
    role_arn           = aws_iam_role.xsiam_kinesis_firehose_role.arn
    s3_backup_mode     = "FailedDataOnly"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.xsiam_delivery_group.name
      log_stream_name = aws_cloudwatch_log_stream.xsiam_delivery_stream.name
    }

    s3_configuration {
      role_arn           = aws_iam_role.xsiam_kinesis_firehose_role.arn
      bucket_arn         = aws_s3_bucket.xsiam_firehose_bucket.arn
      buffering_size     = 10
      buffering_interval = 400
      compression_format = "GZIP"
    }

    request_configuration {
      content_encoding = "GZIP"

      common_attributes {
        name  = "business_area"
        value = var.tags_prefix
      }
    }

  }
}

resource "aws_s3_bucket" "xsiam_firehose_bucket" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  bucket = "${var.tags_prefix}-${var.environment}-xsiam-firehose-bucket"
   tags  = try(var.tags_common,{})
}

resource "aws_cloudwatch_log_group" "xsiam_delivery_group" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  name              = "${var.tags_prefix}-${var.environment}-xsiam-delivery-group"
  tags              = try(var.tags_common,{})
  retention_in_days = 90
}

resource "aws_cloudwatch_log_stream" "xsiam_delivery_stream" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  name           = "${var.tags_prefix}-${var.environment}-errors"
  log_group_name = aws_cloudwatch_log_group.xsiam_delivery_group.name
}

resource "aws_iam_role" "xsiam_kinesis_firehose_role" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  name = "${var.tags_prefix}-xsiam-delivery-stream-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = try(var.tags_common,{})
}

resource "aws_iam_role_policy" "xsiam_kinesis_firehose_role_policy" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing. 
 
  role = aws_iam_role.xsiam_kinesis_firehose_role.id

  name = "${var.tags_prefix}-xsiam_kinesis_firehose_role_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "log-access"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      }
    ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "kinesis_firehose_error_log_role_attachment" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  policy_arn = aws_iam_policy.xsiam_kinesis_firehose_error_log_policy.arn
  role       = aws_iam_role.xsiam_kinesis_firehose_role.name

}

resource "aws_iam_policy" "xsiam_kinesis_firehose_error_log_policy" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  name = "${var.tags_prefix}-xsiam_kinesis_firehose_error_log_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:PutLogEvents",
        ]
        Effect = "Allow"
        Resource = [
          "${aws_cloudwatch_log_group.xsiam_delivery_group.arn}/*"
        ]
      }
    ]
  })

  tags = try(var.tags_common,{})
}

resource "aws_iam_role_policy_attachment" "kinesis_role_attachment" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing. 
  policy_arn = aws_iam_policy.s3_kinesis_xsiam_policy.arn
  role       = aws_iam_role.xsiam_kinesis_firehose_role.name

}

resource "aws_iam_policy" "s3_kinesis_xsiam_policy" {
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax. 
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  name = "${var.tags_prefix}-s3_kinesis_xsiam_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.xsiam_firehose_bucket.arn,
          "${aws_s3_bucket.xsiam_firehose_bucket.arn}/*"
        ]
      }
    ]
  })

  tags = try(var.tags_common,{})
}

resource "aws_cloudwatch_log_subscription_filter" "nacs_server_xsiam_subscription" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  name            = "${var.tags_prefix}-nacs_server_xsiam_subscription"
  role_arn        = aws_iam_role.this.arn
  log_group_name  = aws_flow_log.cloudwatch.log_group_name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.firehose_stream.arn
}

resource "aws_iam_role" "put_record_role" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  name_prefix        = "${var.tags_prefix}-put_record_role"
  tags               = try(var.tags_common,{})
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "logs.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "put_record_policy" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing. 
  name_prefix = "${var.tags_prefix}-put_record_policy"
  tags        = try(var.tags_common,{})
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "firehose:PutRecord",
                "firehose:PutRecordBatch"
            ],
            "Resource": [
                "${aws_kinesis_firehose_delivery_stream.firehose_stream.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "put_record_policy_attachment" {
  count = var.build_firehose ? 1 : 0  # Builds the resource if this var is true, else do nothing.
  role       = aws_iam_role.put_record_role.arn
  policy_arn = aws_iam_policy.put_record_policy.arn
}
