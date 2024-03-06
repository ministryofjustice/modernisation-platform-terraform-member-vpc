
# Sharing log data with SecOps via AWS Firehose & a subscription on the cloudwatch log that contains flow log data.

# To build the firehose resources we want the following to be true:
# - var.build_firehose is true
# - var.kinesis_endpoint_url has a value.
# This ensures that we don't try and build the resources without an endpoint provided.

# Note that var.tags_prefix includes the environment name so we don't need to include that in the name as a separate variable.


resource "aws_kinesis_firehose_delivery_stream" "firehose_stream" {
  #checkov:skip=CKV_AWS_241: We are using the default key for encryption.
  count = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0

  name        = "${var.tags_prefix}-xsiam-delivery-stream"
  destination = "http_endpoint"

  tags = try(var.tags_common, {})

  server_side_encryption {
    enabled = true    
  }

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

resource "aws_cloudwatch_log_group" "xsiam_delivery_group" {
  #checkov:skip=CKV_AWS_158:"Temporarily skip KMS encryption check while logging solution is being updated"
  count             = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  name              = "${var.tags_prefix}-xsiam-delivery-group"
  tags              = try(var.tags_common, {})
  retention_in_days = 366
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

#tfsec:ignore:aws-iam-no-policy-wildcards - We are keeping this 
resource "aws_iam_role_policy" "xsiam_kinesis_firehose_role_policy" {
  #checkov:skip=CKV_AWS_355: - Ignore for now whilst we look into this.
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

#tfsec:ignore:aws-iam-no-policy-wildcards - this is to allow s3:AbortMultiPartUpload.
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
          aws_s3_bucket.xsiam_firehose_bucket[count.index].arn,
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


# S3 Bucket to hold the transfer failure logs. We are using the default s3 key and no logging as it is not needed. We also have public access blocked by default

#tfsec:ignore:aws-ssm-secret-use-customer-key
#tfsec:ignore:aws-s3-encryption-customer-key
#tfsec:ignore:aws-s3-enable-bucket-logging
#tfsec:ignore:aws-s3-specify-public-access-block
resource "aws_s3_bucket" "xsiam_firehose_bucket" {
  #checkov:skip=CKV_AWS_241: We have encryption already in place using the default s3 kms key.
  #checkov:skip=CKV_AWS_21: We already have versioning enabled.
  #checkov:skip=CKV_AWS_145: We use the default encryption key.
  #checkov:skip=CKV2_AWS_62: We do not need event notifications enabled.
  #checkov:skip=CKV_AWS_144: We are not using cross-region replication.
  #checkov:skip=CKV_AWS_18: No access logging required
  #checkov:skip=CKV2_AWS_61: Lifecycle is enabled but this error still gets thrown.
  #checkov:skip=CKV2_AWS_6: Public Access Block enabled - see below - but the error still gets thrown.
  count  = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  bucket = "${var.tags_prefix}-xsiam-firehose-bucket"
  tags   = try(var.tags_common, {})
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "xsiam_firehose_bucket_encryption" {
  count  = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  bucket = aws_s3_bucket.xsiam_firehose_bucket[count.index].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "xsiam_firehose_bucket_config" {
  #checkov:skip=CKV_AWS_300: Event notifications not used.
  count  = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  bucket = aws_s3_bucket.xsiam_firehose_bucket[count.index].id
  rule {
    id = "delete-old"
    expiration {
      days = 366
    }
    status = "Enabled"
    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

# Ideally we would not be using versioning of s3 files but it's added for the tfsec & checkov checks.
resource "aws_s3_bucket_versioning" "xsiam_firehose_bucket_versioning" {
  count  = var.build_firehose && length(var.kinesis_endpoint_url) > 0 ? 1 : 0
  bucket = aws_s3_bucket.xsiam_firehose_bucket[count.index].id
  versioning_configuration {
    status = "Enabled"
  }
}

# By default s3 already blocks public access but this added for the tfsec & checkov checks.
resource "aws_s3_bucket_public_access_block" "xsiam_firehose_bucket_block_public" {
  bucket = aws_s3_bucket.xsiam_firehose_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}