# This data sources allows us to get the Modernisation Platform account information for use elsewhere
# (when we want to assume a role in the MP, for instance)
data "aws_organizations_organization" "root_account" {}

# Get the environments file from the main repository
data "http" "environments_file" {
  url = "https://raw.githubusercontent.com/ministryofjustice/modernisation-platform/main/environments/${local.application_name}.json"
}

locals {

  application_name      = "testing"
  vpc_flow_log_iam_role = "arn:aws:iam::${local.environment_management.account_ids["testing-test"]}:role/TestingTestMemberInfrastructureAccess"

  environment_management = jsondecode(data.aws_secretsmanager_secret_version.environment_management.secret_string)

  # This takes the name of the Terraform workspace (e.g. core-vpc-production), strips out the application name (e.g. core-vpc), and checks if
  # the string leftover is `-production`, if it isn't (e.g. core-vpc-non-production => -non-production) then it sets the var to false.
  is-production    = substr(terraform.workspace, length(local.application_name), length(terraform.workspace)) == "-production"
  is-preproduction = substr(terraform.workspace, length(local.application_name), length(terraform.workspace)) == "-preproduction"
  is-test          = substr(terraform.workspace, length(local.application_name), length(terraform.workspace)) == "-test"
  is-development   = substr(terraform.workspace, length(local.application_name), length(terraform.workspace)) == "-development"

  # Merge tags from the environment json file with additional ones
  tags = merge(
    jsondecode(data.http.environments_file.response_body).tags,
    { "is-production" = local.is-production },
    { "environment-name" = terraform.workspace },
    { "source-code" = "https://github.com/ministryofjustice/modernisation-platform" }
  )

  tags_common = {
    Name        = "testing"
    Environment = "test"
  }

  tags_prefix = "testing"

  environment = "test"
  vpc_name    = var.networking[0].business-unit
  subnet_set  = var.networking[0].set
  subnet_sets = {
    "general" = "192.168.0.0/20"
  }
  # transit_gateway_id    = var.networking[0].transit_gateway_id
  additional_endpoints  = ["com.amazonaws.eu-west-2.secretsmanager"]
  secondary_cidr_blocks = ["192.168.16.0/20"]

  is_live       = [substr("testing-test", length(local.application_name), length(terraform.workspace)) == "-production" || substr(terraform.workspace, length(local.application_name), length(terraform.workspace)) == "-preproduction" ? "live" : "non-live"]
  provider_name = "core-vpc-${local.environment}"

  availability_zones = sort(data.aws_availability_zones.available.names)


  # Protected subnets
  # get protected subnet cidr from spare /23 in first defined subnet-set for the vpc
  protected_cidr = {
    for index, item in local.subnet_sets :
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
    for key, subnet_set in local.subnet_sets :
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
    local.additional_endpoints
  )

  # Secondary CIDR blocks
  # All secondary CIDRs are treated as 'general' type and split into private/public/data subnets
  expanded_secondary_cidr_subnets = {
    for cidr_block in local.secondary_cidr_blocks :
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
