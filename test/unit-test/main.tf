# Get AZs for account
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = local.subnet_sets["general"]

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.tags_common,
    {
      Name = local.tags_prefix
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
    local.tags_common,
    {
      Name = "${local.tags_prefix}-default"
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
  name              = "${local.tags_prefix}-vpc-flow-logs-${random_id.flow_logs.hex}"
  retention_in_days = 731 # 0 = never expire
}

resource "aws_flow_log" "cloudwatch" {
  iam_role_arn             = local.vpc_flow_log_iam_role
  log_destination          = aws_cloudwatch_log_group.default.arn
  max_aggregation_interval = "60"
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  vpc_id                   = aws_vpc.vpc.id

  tags = merge(
    local.tags_common,
    {
      Name = "${local.tags_prefix}-vpc-flow-logs-${random_id.flow_logs.hex}"
    }
  )
}

resource "aws_vpc_ipv4_cidr_block_association" "subnet_sets" {
  for_each = {
    for k, v in tomap(local.subnet_sets) :
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
    local.tags_common,
    {
      Name = "${local.tags_prefix}-${each.key}"
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
    local.tags_common,
    {
      Name = "${local.tags_prefix}-${each.key}"
    }
  )
}

# VPC: Internet Gateway
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    local.tags_common,
    {
      Name = "${local.tags_prefix}-internet-gateway"
    },
  )
}

resource "aws_route_table" "route_tables" {
  for_each = tomap(local.all_distinct_route_tables_with_keys)

  vpc_id = aws_vpc.vpc.id

  tags = merge(
    local.tags_common,
    {
      Name = "${local.tags_prefix}-${each.value}"
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

# resource "aws_route" "transit_gateway" {
#   for_each = {
#     for key, route_table in aws_route_table.route_tables :
#     key => route_table
#     if substr(key, length(key) - 6, length(key)) != "public"
#   }

#   route_table_id         = aws_route_table.route_tables[each.key].id
#   destination_cidr_block = "0.0.0.0/0"
#   transit_gateway_id     = local.transit_gateway_id
# }

resource "aws_route_table" "protected" {

  vpc_id = aws_vpc.vpc.id

  tags = merge(
    local.tags_common,
    {
      Name = "${local.tags_prefix}-protected"
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

  name        = "${local.tags_prefix}-int-endpoint"
  description = "Control interface traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(
    local.tags_common,
    {
      Name = "${local.tags_prefix}-int-endpoint"
    }
  )
}
resource "aws_security_group_rule" "endpoints_ingress_1" {
  for_each = local.subnet_sets

  description       = "Allow inbound HTTPS"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.endpoints.id

}
resource "aws_security_group_rule" "endpoints_ingress_2" {
  for_each = local.subnet_sets

  description       = "Allow inbound SMTP"
  type              = "ingress"
  from_port         = 25
  to_port           = 25
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.endpoints.id

}
resource "aws_security_group_rule" "endpoints_ingress_3" {
  for_each = local.subnet_sets

  description       = "Allow inbound SMTP-TLS"
  type              = "ingress"
  from_port         = 587
  to_port           = 587
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.endpoints.id

}

resource "aws_security_group_rule" "endpoints_ingress_4" {
  for_each = local.subnet_sets

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
    local.tags_common,
    {
      Name = "${local.tags_prefix}-${each.key}"
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
    local.tags_common,
    {
      Name = "${local.tags_prefix}-com.amazonaws.eu-west-2.s3"
    }
  )
}
