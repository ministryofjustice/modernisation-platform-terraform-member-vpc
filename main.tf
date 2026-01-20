# Get AZs for account
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

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
    "com.amazonaws.${data.aws_region.current.region}.ec2",
    "com.amazonaws.${data.aws_region.current.region}.ec2messages",
    "com.amazonaws.${data.aws_region.current.region}.ssm",
    "com.amazonaws.${data.aws_region.current.region}.ssmmessages",
  ]

  # Merge SSM endpoints with VPC requested endpoints
  merged_endpoint_list = concat(
    local.ssm_endpoints,
    var.additional_endpoints
  )

  # Custom VPC flow log statement
  custom_flow_log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${sublocation-type} $${sublocation-id} $${pkt-src-aws-service} $${pkt-dst-aws-service} $${flow-direction} $${traffic-path}"

  # Secondary CIDR blocks
  # All secondary CIDRs are treated as 'general' type and split into private/public/data subnets
  expanded_secondary_cidr_subnets = {
    for cidr_block in var.secondary_cidr_blocks :
    cidr_block => chunklist(cidrsubnets(cidr_block, 3, 3, 3, 4, 4, 4, 4, 4, 4), 3)
  }

  secondary_cidr_subnets_assocation = flatten([
    for cidr_block, cidr_set in local.expanded_secondary_cidr_subnets : [
      for set_index, set in cidr_set : [
        for cidr_index, cidr in set : {
          key              = "general"
          cidr             = cidr
          az               = local.availability_zones[cidr_index]
          type             = set_index == 0 ? "private" : (set_index == 1 ? "public" : "data")
          group            = "general"
          cidr_block_key   = cidr_block
        }
      ]
    ]
  ])

  secondary_cidr_subnets_with_keys = {
    for subnet in local.secondary_cidr_subnets_assocation :
    "${subnet.cidr_block_key}-${subnet.type}-${subnet.az}-secondary" => subnet
  }
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
  log_destination_type     = "cloud-watch-logs"
  log_format               = local.custom_flow_log_format
  max_aggregation_interval = "60"
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-vpc-flow-logs-${random_id.flow_logs.hex}"
    }
  )
}

resource "aws_flow_log" "s3" {
  for_each                 = var.flow_log_s3_destination_arn != "" ? toset([var.flow_log_s3_destination_arn]) : toset([])
  log_destination          = each.key
  log_destination_type     = "s3"
  log_format               = local.custom_flow_log_format
  max_aggregation_interval = "60"
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-vpc-flow-logs-s3-${random_id.flow_logs.hex}"
    }
  )
}

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
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    for value in local.all_distinct_route_table_associations :
    aws_route_table.route_tables[value].id
  ]

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-com.amazonaws.${data.aws_region.current.region}.s3"
    }
  )
}

# Secondary CIDR Blocks
# Associate secondary CIDR blocks to the VPC
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  for_each = toset(var.secondary_cidr_blocks)

  cidr_block = each.value
  vpc_id     = aws_vpc.vpc.id
}

# Create subnets from secondary CIDR blocks (private, public, data)
resource "aws_subnet" "secondary_cidr_subnets" {
  for_each = local.secondary_cidr_subnets_with_keys

  availability_zone = each.value.az
  cidr_block        = each.value.cidr
  vpc_id            = aws_vpc.vpc.id

  tags = merge(
    var.tags_common,
    {
      Name = "${var.tags_prefix}-${each.value.key}-${each.value.type}-secondary-${each.value.az}"
    }
  )

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}

# Route table associations for secondary CIDR subnets
# Secondary subnets use the same route tables as their corresponding primary subnet type
resource "aws_route_table_association" "secondary_cidr_subnets" {
  for_each = aws_subnet.secondary_cidr_subnets

  route_table_id = aws_route_table.route_tables["${local.secondary_cidr_subnets_with_keys[each.key].key}-${local.secondary_cidr_subnets_with_keys[each.key].type}"].id
  subnet_id      = each.value.id
}

# Network ACL associations for secondary CIDR subnets
# Secondary subnets use the same NACLs as their corresponding primary subnet type
resource "aws_network_acl_association" "secondary_cidr_subnets" {
  for_each = aws_subnet.secondary_cidr_subnets

  network_acl_id = local.secondary_cidr_subnets_with_keys[each.key].type == "protected" ? aws_network_acl.protected.id : aws_network_acl.nacl[local.secondary_cidr_subnets_with_keys[each.key].type].id
  subnet_id      = each.value.id
}
