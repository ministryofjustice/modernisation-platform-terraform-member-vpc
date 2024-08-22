output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}

output "tgw_subnet_ids" {
  description = "Transit Gateway subnet IDs"
  value = [
    for key, subnet in aws_subnet.subnets :
    subnet.id
    if substr(key, 0, 15) == "transit-gateway"
  ]
}

output "non_tgw_subnet_arns" {
  description = "Non-Transit Gateway and Protected subnet ARNs"
  value = concat(
    [for key, subnet in aws_subnet.subnets : subnet.arn if substr(key, 0, 15) != "transit-gateway"],
    [for key, subnet in aws_subnet.protected : subnet.arn if substr(key, 0, 15) != "transit-gateway"]
  )
}

output "non_tgw_subnet_arns_by_set" {
  value = {
    for set, cidr in var.subnet_sets :
    set => {
      for key, subnet in local.expanded_worker_subnets_assocation :
      "${key}-${cidr}" => aws_subnet.subnets[key].arn
      if substr(key, 0, length(set)) == set
    }
  }
}

output "non_tgw_subnet_arns_by_subnetset" {
  value = merge({
    for set, cidr in var.subnet_sets : set =>
    {
      for key, subnet in local.expanded_worker_subnets_assocation :
      "${key}-${cidr}" => aws_subnet.subnets["${subnet.key}-${subnet.type}-${subnet.az}"].arn
      if substr(subnet.key, 0, length(set)) == set
    }
    },
    { "protected" = { for key, subnet in aws_subnet.protected : key => subnet.arn }
  })
}

output "expanded_worker_subnets_assocation" {
  value = local.expanded_worker_subnets_assocation
}

output "expanded_worker_subnets_with_keys" {
  value = local.expanded_worker_subnets_with_keys
}

output "data_subnet_ids" {
  value = [for v in aws_subnet.subnets : v.id if(length(regexall("(?:data)", v.tags.Name)) > 0)]
}

output "private_subnet_ids" {
  value = [for v in aws_subnet.subnets : v.id if(length(regexall("(?:private)", v.tags.Name)) > 0)]
}

output "public_subnet_ids" {
  value = [for v in aws_subnet.subnets : v.id if(length(regexall("(?:public)", v.tags.Name)) > 0)]
}

output "protected_subnet_ids" {
  value = [for v in aws_subnet.protected : v.id if(length(regexall("(?:protected)", v.tags.Name)) > 0)]
}

output "private_route_tables" {
  value = {
    for key, value in local.all_distinct_route_tables_with_keys :
    key => aws_route_table.route_tables[key].id
    if substr(key, length(key) - 6, length(key)) != "public"
  }
}

output "vpc_flow_log" {
  value = aws_cloudwatch_log_group.default.name
}
