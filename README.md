# Modernisation Platform Terraform Member VPC Module
[![repo standards badge](https://img.shields.io/badge/dynamic/json?color=blue&style=for-the-badge&logo=github&label=MoJ%20Compliant&query=%24.data%5B%3F%28%40.name%20%3D%3D%20%22modernisation-platform-terraform-member-vpc%22%29%5D.status&url=https%3A%2F%2Foperations-engineering-reports.cloud-platform.service.justice.gov.uk%2Fgithub_repositories)](https://operations-engineering-reports.cloud-platform.service.justice.gov.uk/github_repositories#modernisation-platform-terraform-member-vpc "Link to report")

This module creates the member accounts VPC and networking.

## Looking for issues?
If you're looking to raise an issue with this module, please create a new issue in the [Modernisation Platform repository](https://github.com/ministryofjustice/modernisation-platform/issues).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 4.0 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_flow_log.cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_internet_gateway.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_route.public_internet_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.protected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.route_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.protected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.route_table_associations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.endpoints_ingress_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.endpoints_ingress_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.endpoints_ingress_3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_subnet.protected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.ssm_interfaces](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ssm_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_ipv4_cidr_block_association.subnet_sets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv4_cidr_block_association) | resource |
| [random_id.flow_logs](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_endpoints"></a> [additional\_endpoints](#input\_additional\_endpoints) | additional endpoints required for VPC | `list(any)` | n/a | yes |
| <a name="input_bastion_linux"></a> [bastion\_linux](#input\_bastion\_linux) | n/a | `bool` | `false` | no |
| <a name="input_bastion_windows"></a> [bastion\_windows](#input\_bastion\_windows) | n/a | `bool` | `false` | no |
| <a name="input_subnet_sets"></a> [subnet\_sets](#input\_subnet\_sets) | n/a | `map(any)` | n/a | yes |
| <a name="input_tags_common"></a> [tags\_common](#input\_tags\_common) | MOJ required tags | `map(string)` | n/a | yes |
| <a name="input_tags_prefix"></a> [tags\_prefix](#input\_tags\_prefix) | prefix for name tags | `string` | n/a | yes |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | tgw ID | `string` | n/a | yes |
| <a name="input_vpc_flow_log_iam_role"></a> [vpc\_flow\_log\_iam\_role](#input\_vpc\_flow\_log\_iam\_role) | VPC Flow Log IAM role ARN for VPC Flow Logs to CloudWatch | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_expanded_worker_subnets_assocation"></a> [expanded\_worker\_subnets\_assocation](#output\_expanded\_worker\_subnets\_assocation) | n/a |
| <a name="output_expanded_worker_subnets_with_keys"></a> [expanded\_worker\_subnets\_with\_keys](#output\_expanded\_worker\_subnets\_with\_keys) | n/a |
| <a name="output_non_tgw_subnet_arns"></a> [non\_tgw\_subnet\_arns](#output\_non\_tgw\_subnet\_arns) | Non-Transit Gateway and Protected subnet ARNs |
| <a name="output_non_tgw_subnet_arns_by_set"></a> [non\_tgw\_subnet\_arns\_by\_set](#output\_non\_tgw\_subnet\_arns\_by\_set) | n/a |
| <a name="output_non_tgw_subnet_arns_by_subnetset"></a> [non\_tgw\_subnet\_arns\_by\_subnetset](#output\_non\_tgw\_subnet\_arns\_by\_subnetset) | n/a |
| <a name="output_private_route_tables"></a> [private\_route\_tables](#output\_private\_route\_tables) | n/a |
| <a name="output_tgw_subnet_ids"></a> [tgw\_subnet\_ids](#output\_tgw\_subnet\_ids) | Transit Gateway subnet IDs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID |
<!-- END_TF_DOCS -->