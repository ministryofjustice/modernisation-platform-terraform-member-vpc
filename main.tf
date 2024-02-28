# Get AZs for account
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = sort(data.aws_availability_zones.available.names)

  # Protected subnets
  # get protected subnet cidr from spare /23 in first defined subnet-set for the vpc
  protected_cidr = {
    for index, item in var.subnet_sets :
    index => cidrsubnet(item, 2, 3)
    if index == "general"
  }

  expanded_protected_subnets = [
    for index, cidr in cidrsubnets(local.protected_cidr["general"], 2, 2, 2) : {
      key  = "protected"
      cidr = cidr
      az   = local.availability_zones[index]
      type = "protected"
    }
  ]
  expanded_protected_subnets_with_keys = {
    for subnet in local.expanded_protected_subnets :
    "${subnet.key}-${subnet.az}" => subnet
  }

  # Transit Gateway subnets

  transit_gateway_cidr = cidrsubnet(local.protected_cidr["general"], 2, 3)

  expanded_tgw_subnets = [
    for index, cidr in cidrsubnets(local.transit_gateway_cidr, 3, 3, 3) : {
      key  = "transit-gateway"
      cidr = cidr
      az   = local.availability_zones[index]
      type = "transit-gateway"
    }
  ]
  expanded_tgw_subnets_with_keys = {
    for subnet in local.expanded_tgw_subnets :
    "${subnet.key}-${subnet.az}" => subnet
  }

  # Worker subnets
  expanded_worker_subnets = {
    for key, subnet_set in var.subnet_sets :
    key => chunklist(cidrsubnets(subnet_set, 3, 3, 3, 4, 4, 4, 4, 4, 4), 3)
  }
  expanded_worker_subnets_assocation = flatten([
    for key, subnet_set in local.expanded_worker_subnets : [
      for set_index, set in subnet_set : [
        for cidr_index, cidr in set : {
          key   = key
          cidr  = cidr
          az    = local.availability_zones[cidr_index]
          type  = set_index == 0 ? "private" : (set_index == 1 ? "public" : "data")
          group = key
        }
      ]
    ]
  ])
  expanded_worker_subnets_with_keys = {
    for subnet in local.expanded_worker_subnets_assocation :
    "${subnet.key}-${subnet.type}-${subnet.az}" => subnet
  }

  # All subnets (TGW and worker subnets)
  all_subnets_with_keys = merge(
    local.expanded_tgw_subnets_with_keys,
    local.expanded_worker_subnets_with_keys,
    # local.expanded_protected_subnets_with_keys
  )

  all_distinct_route_tables_with_keys = {
    for rt in local.all_distinct_route_tables :
    rt => rt
  }
  # All distinct route tables
  all_distinct_route_tables = distinct([
    for subnet in local.all_subnets_with_keys :
    "${subnet.key}-${subnet.type}"
  ])

  # All distinct route table associations
  all_distinct_route_table_associations = {
    for key, subnet in local.all_subnets_with_keys :
    key => "${subnet.key}-${subnet.type}"
  }

  # SSM Endpoints (Systems Session Manager)
  ssm_endpoints = [
    "com.amazonaws.eu-west-2.ec2",
    "com.amazonaws.eu-west-2.ec2messages",
    "com.amazonaws.eu-west-2.ssm",
    "com.amazonaws.eu-west-2.ssmmessages",
  ]

  # Merge SSM endpoints with VPC requested endpoints
  merged_endpoint_list = concat(
    local.ssm_endpoints,
    var.additional_endpoints
  )

}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.subnet_sets["general"]

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags_common,
    {
      Name = var.tags_prefix
    },
  )
}

# Bring management of the default security group in the member vpc under terraform
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id

  # Block all inbound and outbound access to through this default security group
  ingress = []
  egress  = []

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-default"
    }
  )
  # For reference, the following inline ingress and egress rules are the 'default' rules which we are effectively removing
  # Uncomment these rules to restore an uncustomised, default security group back to what it was originally
  # See https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/default-custom-security-groups.html#default-security-group for more info
  # ingress = [
  #   {
  #     protocol  = -1
  #     self      = true
  #     from_port = 0
  #     to_port   = 0
  #   }
  # ]

  # egress = [
  #   {
  #     from_port   = 0
  #     to_port     = 0
  #     protocol    = "-1"
  #     cidr_blocks = ["0.0.0.0/0"]
  #   }
  # ]
}

# VPC Flow Logs
# TF sec exclusions
# - Ignore warnings regarding log groups not encrypted using customer-managed KMS keys - following cost/benefit discussion and longer term plans for logging solution
#tfsec:ignore:AWS089

resource "random_id" "flow_logs" {

  keepers = {
    # Generate a new id each time we regenerate a vpc
    vpc_id = aws_vpc.vpc.cidr_block
  }

  byte_length = 4
}

#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "default" {
  #checkov:skip=CKV_AWS_158:"Temporarily skip KMS encryption check while logging solution is being updated"
  name              = "${var.tags_prefix}-vpc-flow-logs-${random_id.flow_logs.hex}"
  retention_in_days = 731 # 0 = never expire
}

resource "aws_flow_log" "cloudwatch" {
  iam_role_arn             = var.vpc_flow_log_iam_role
  log_destination          = aws_cloudwatch_log_group.default.arn
  max_aggregation_interval = "60"
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  vpc_id                   = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-vpc-flow-logs-${random_id.flow_logs.hex}"
    }
  )
}






####### START OF FIREHOSE SOURCE





# Sharing log data with SecOps via Firehose

locals {

  environment  = "development"
  mp_prefix    = "mod_platform"
  endpoint_url = "https://api-justiceukpreprod.xdr.uk.paloaltonetworks.com/logs/v1/aws"
  access_key   = ""

  tags = {
    application = "modernisation_platform"
  }

  secret_version_arn = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${data.aws_secretsmanager_secret.xsiam_preprod_network_secret.name}-${data.aws_secretsmanager_secret_version.xsiam_preprod_network_secret.version_stage}"

}

data "aws_secretsmanager_secret_version" "xsiam_preprod_network_secret" {
  secret_id = "xsiam_preprod_network_secret"
}

resource "aws_flow_log" "firehose" {
  iam_role_arn             = var.vpc_flow_log_iam_role
  log_destination          = aws_kinesis_firehose_delivery_stream.firehose_stream.arn
  max_aggregation_interval = "60"
  traffic_type             = "ALL"
  log_destination_type     = "firehose"
  vpc_id                   = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-vpc-flow-log-firehose-${random_id.flow_logs.hex}"
    }
  )
}


resource "aws_kinesis_firehose_delivery_stream" "firehose_stream" {
  name        = "${var.tags_prefix}-xsiam-delivery-stream"
  destination = "http_endpoint"

  tags = try(local.tags, {})

  http_endpoint_configuration {
    url                = local.endpoint_url
    name               = local.mp_prefix
    access_key         = data.aws_secretsmanager_secret_version.xsiam_preprod_network_secret.secret_string
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

# Using an environment local for now as S3 bucket names are global

resource "aws_s3_bucket" "xsiam_firehose_bucket" {
  bucket = "${var.tags_prefix}-${local.environment}-xsiam-firehose"
  tags   = try(local.tags, {})
}

resource "aws_cloudwatch_log_group" "xsiam_delivery_group" {
  name              = "${var.tags_prefix}-xsiam-delivery-stream-${local.mp_prefix}"
  tags              = try(local.tags, {})
  retention_in_days = 90
}

resource "aws_cloudwatch_log_stream" "xsiam_delivery_stream" {
  name           = "${var.tags_prefix}-errors"
  log_group_name = aws_cloudwatch_log_group.xsiam_delivery_group.name
}



resource "aws_iam_role" "xsiam_kinesis_firehose_role" {

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

  tags = try(local.tags, {})
}

resource "aws_iam_role_policy" "xsiam_kinesis_firehose_role_policy" {
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
      },
      {
        Sid    = "secretsmanager"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = "${secret_version_arn}"
      }
    ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "kinesis_firehose_error_log_role_attachment" {
  policy_arn = aws_iam_policy.xsiam_kinesis_firehose_error_log_policy.arn
  role       = aws_iam_role.xsiam_kinesis_firehose_role.name

}

resource "aws_iam_policy" "xsiam_kinesis_firehose_error_log_policy" {
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

  tags = try(local.tags, {})
}


resource "aws_iam_role_policy_attachment" "kinesis_role_attachment" {
  policy_arn = aws_iam_policy.s3_kinesis_xsiam_policy.arn
  role       = aws_iam_role.xsiam_kinesis_firehose_role.name

}

resource "aws_iam_policy" "s3_kinesis_xsiam_policy" {

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
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

  tags = try(local.tags, {})
}



resource "aws_cloudwatch_log_subscription_filter" "nacs_server_xsiam_subscription" {
  name            = "${var.tags_prefix}-nacs_server_xsiam_subscription"
  role_arn        = aws_iam_role.this.arn
  log_group_name  = aws_flow_log.cloudwatch.log_group_name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.xsiam_delivery_stream.arn
}

resource "aws_iam_role" "this" {
  name_prefix        = var.tags_prefix
  tags               = try(local.tags, {})
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

resource "aws_iam_policy" "put_record" {
  name_prefix = "${var.tags_prefix}-put_record"
  tags        = try(local.tags, {})
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
                "${aws_kinesis_firehose_delivery_stream.xsiam_delivery_stream.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.put_record.arn
}



















####### END OF FIREHOSE SOURCE






resource "aws_vpc_ipv4_cidr_block_association" "subnet_sets" {
  for_each = {
    for k, v in tomap(var.subnet_sets) :
    k => v
    if k != "general"
  }

  vpc_id     = aws_vpc.vpc.id
  cidr_block = each.value
}

# VPC: Subnet per type, per availability zone
resource "aws_subnet" "subnets" {
  depends_on = [aws_vpc_ipv4_cidr_block_association.subnet_sets]

  for_each = tomap(local.all_subnets_with_keys)

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-${each.key}"
    }
  )
}

# Protected Subnets
resource "aws_subnet" "protected" {

  for_each = tomap(local.expanded_protected_subnets_with_keys)

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-${each.key}"
    }
  )
}

# VPC: Internet Gateway
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-internet-gateway"
    },
  )
}

resource "aws_route_table" "route_tables" {
  for_each = tomap(local.all_distinct_route_tables_with_keys)

  vpc_id = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-${each.value}"
    }
  )
}
resource "aws_route_table_association" "route_table_associations" {
  for_each = tomap(local.all_distinct_route_table_associations)

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.route_tables[each.value].id
}
resource "aws_route" "public_internet_gateway" {
  for_each = {
    for key, route_table in aws_route_table.route_tables :
    key => route_table
    if substr(key, length(key) - 6, length(key)) == "public"
  }

  route_table_id         = aws_route_table.route_tables[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

resource "aws_route" "transit_gateway" {
  for_each = {
    for key, route_table in aws_route_table.route_tables :
    key => route_table
    if substr(key, length(key) - 6, length(key)) != "public"
  }

  route_table_id         = aws_route_table.route_tables[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id
}

resource "aws_route_table" "protected" {

  vpc_id = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-protected"
    }
  )
}
resource "aws_route_table_association" "protected" {
  for_each = aws_subnet.protected

  subnet_id      = each.value.id
  route_table_id = aws_route_table.protected.id
}


# SSM Security Groups
resource "aws_security_group" "endpoints" {

  name        = "${var.tags_prefix}-int-endpoint"
  description = "Control interface traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-int-endpoint"
    }
  )
}
resource "aws_security_group_rule" "endpoints_ingress_1" {
  for_each = var.subnet_sets

  description       = "Allow inbound HTTPS"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.endpoints.id

}
resource "aws_security_group_rule" "endpoints_ingress_2" {
  for_each = var.subnet_sets

  description       = "Allow inbound SMTP"
  type              = "ingress"
  from_port         = 25
  to_port           = 25
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.endpoints.id

}
resource "aws_security_group_rule" "endpoints_ingress_3" {
  for_each = var.subnet_sets

  description       = "Allow inbound SMTP-TLS"
  type              = "ingress"
  from_port         = 587
  to_port           = 587
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.endpoints.id

}

resource "aws_security_group_rule" "endpoints_ingress_4" {
  for_each = var.subnet_sets

  description       = "Allow inbound Redshift"
  type              = "ingress"
  from_port         = 5439
  to_port           = 5439
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.endpoints.id

}
# SSM Endpoints
resource "aws_vpc_endpoint" "ssm_interfaces" {
  for_each = toset(local.merged_endpoint_list)

  vpc_id            = aws_vpc.vpc.id
  service_name      = each.value
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    for az in local.availability_zones :
    aws_subnet.protected["protected-${az}"].id
  ]
  security_group_ids = [aws_security_group.endpoints.id]

  private_dns_enabled = true

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-${each.key}"
    }
  )
}

resource "aws_vpc_endpoint" "ssm_s3" {

  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.eu-west-2.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    for value in local.all_distinct_route_table_associations :
    aws_route_table.route_tables[value].id
  ]

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-com.amazonaws.eu-west-2.s3"
    }
  )
}