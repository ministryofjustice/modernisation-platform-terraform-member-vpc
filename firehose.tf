
# Sharing log data with SecOps via Firehose.check "name".check "name"

# To build the firehose resources we want the following to be true:
# - var.build_firehose is true
# - var.kinesis_endpoint_url has a value.
# This ensures that we don't try and build the resources without an endpoint provided.

# Note that var.tags_prefix includes the environment name so we don't need to include that in the name as a separate variable.



# resource "aws_cloudwatch_log_destination" "kinesis_endpoint_destination" {
#   name       = "${var.tags_prefix}-kinesis_endpoint_destination-destination"
#   role_arn   = aws_iam_role.iam_for_cloudwatch.arn # needs to be a secret
#   target_arn = aws_kinesis_stream.kinesis_for_cloudwatch.arn # arn of the endpoint?
# }

# We don't need a new flow log as we have a subscription to the existing log. This is only needed if we are transfering data to a firehose stream in another account.

# resource "aws_flow_log" "firehose" {
#   count                    = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0 # Builds the resource if this var is true, else do nothing.
#   iam_role_arn             = var.vpc_flow_log_iam_role
#   log_destination          = aws_kinesis_firehose_delivery_stream.firehose_stream[count.index].arn
#   max_aggregation_interval = "60"
#   traffic_type             = "ALL"
#   log_destination_type     = "kinesis-data-firehose"
#   vpc_id                   = aws_vpc.vpc.id

#   tags = merge(
#     var.tags_common,
#     {
#       Name = "${var.tags_prefix}-vpc-flow-log-firehose-${random_id.flow_logs.hex}"
#     }
#   )
# }



resource "aws_kinesis_firehose_delivery_stream" "firehose_stream" {
  count = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0

  name        = "${var.tags_prefix}-xsiam-delivery-stream"
  destination = "http_endpoint"

  tags = try(var.tags_common, {})

  http_endpoint_configuration {
    url                = var.kinesis_endpoint_url
    name               = "${var.tags_prefix}-endpoint"
    access_key         = var.kinesis_endpoint_secret_string
    buffering_size     = 5
    buffering_interval = 300
    role_arn           = aws_iam_role.xsiam_kinesis_firehose_role[count.index].arn
    s3_backup_mode     = "FailedDataOnly"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.xsiam_delivery_group[count.index].name
      log_stream_name = aws_cloudwatch_log_stream.xsiam_delivery_stream[count.index].name
    }

    s3_configuration {
      role_arn           = aws_iam_role.xsiam_kinesis_firehose_role[count.index].arn
      bucket_arn         = aws_s3_bucket.xsiam_firehose_bucket[count.index].arn
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
  count  = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  bucket = "${var.tags_prefix}-xsiam-firehose-bucket"
  tags   = try(var.tags_common, {})
}

resource "aws_cloudwatch_log_group" "xsiam_delivery_group" {
  count             = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  name              = "${var.tags_prefix}-xsiam-delivery-group"
  tags              = try(var.tags_common, {})
  retention_in_days = 90
}

resource "aws_cloudwatch_log_stream" "xsiam_delivery_stream" {
  count          = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  name           = "${var.tags_prefix}-errors"
  log_group_name = aws_cloudwatch_log_group.xsiam_delivery_group[count.index].name
}

resource "aws_iam_role" "xsiam_kinesis_firehose_role" {
  count = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  name  = "${var.tags_prefix}-xsiam-delivery-stream-role"
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

  tags = try(var.tags_common, {})
}

resource "aws_iam_role_policy" "xsiam_kinesis_firehose_role_policy" {
  count = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0

  role = aws_iam_role.xsiam_kinesis_firehose_role[count.index].id

  name = "${var.tags_prefix}-xsiam-kinesis-firehose-role-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "logaccess"
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
  count      = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  policy_arn = aws_iam_policy.xsiam_kinesis_firehose_error_log_policy[count.index].arn
  role       = aws_iam_role.xsiam_kinesis_firehose_role[count.index].name

}

resource "aws_iam_policy" "xsiam_kinesis_firehose_error_log_policy" {
  count = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  name  = "${var.tags_prefix}-xsiam-kinesis-firehose-error-log-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:PutLogEvents",
        ]
        Effect = "Allow"
        Resource = [
          "${aws_cloudwatch_log_group.xsiam_delivery_group[count.index].arn}/*"
        ]
      }
    ]
  })

  tags = try(var.tags_common, {})
}

resource "aws_iam_role_policy_attachment" "kinesis_role_attachment" {
  count      = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  policy_arn = aws_iam_policy.s3_kinesis_xsiam_policy[count.index].arn
  role       = aws_iam_role.xsiam_kinesis_firehose_role[count.index].name

}

resource "aws_iam_policy" "s3_kinesis_xsiam_policy" {
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax. 
  count = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  name  = "${var.tags_prefix}-s3-kinesis-xsiam-policy"
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
          "${aws_s3_bucket.xsiam_firehose_bucket[count.index].arn}",
          "${aws_s3_bucket.xsiam_firehose_bucket[count.index].arn}/*"
        ]
      }
    ]
  })

  tags = try(var.tags_common, {})
}

# Cloudwatch Log Subscription Filter & IAM Resources. 
# This acts as the interface between the flow log data in cloudwatch & the Firehose Stream.

resource "aws_cloudwatch_log_subscription_filter" "nacs_server_xsiam_subscription" {
  count           = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  name            = "${var.tags_prefix}-nacs_server_xsiam_subscription"
  role_arn        = aws_iam_role.put_record_role[count.index].arn
  log_group_name  = aws_flow_log.cloudwatch.log_group_name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.firehose_stream[count.index].arn
}

resource "aws_iam_role" "put_record_role" {
  count              = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  name_prefix        = "${var.tags_prefix}-put-record-role"
  tags               = try(var.tags_common, {})
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
  count       = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  name_prefix = "${var.tags_prefix}-put-record-policy"
  tags        = try(var.tags_common, {})
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
                "${aws_kinesis_firehose_delivery_stream.firehose_stream[count.index].arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "put_record_policy_attachment" {
  count      = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  role       = aws_iam_role.put_record_role[count.index].name
  policy_arn = aws_iam_policy.put_record_policy[count.index].arn
}

