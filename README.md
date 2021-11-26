# Ministry of Justice Template Repository

Use this template to [create a repository] with the default initial files for a Ministry of Justice Github repository, including:

* The correct LICENSE
* Github actions
* .gitignore file

Once you have created your repository, please:

* Edit the copy of this README.md file to document your project
* Grant permissions to the appropriate MoJ teams
* Setup branch protection

[create a repository]: https://github.com/ministryofjustice/template-repository/generate

<!--- BEGIN_TF_DOCS --->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.47.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.47.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.scaling_policy_down](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.scaling_policy_up](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.scaling_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_autoscaling_group.cluster-scaling-group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_log_group.cloudwatch_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_stream.cloudwatch_stream](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_ecs_capacity_provider.capacity_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider) | resource |
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.linux_ecs_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_ecs_task_definition.windows_ecs_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_instance_profile.ec2_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.ec2_instance_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ecs_task_execution_s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.ec2_instance_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.attach_ec2_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_secrets_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_service_linked_role.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_launch_template.ec2-launch-template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_security_group.cluster_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ecs_task_definition.task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_task_definition) | data source |
| [aws_iam_policy_document.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_lb_target_group.target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_target_group) | data source |
| [aws_security_group.loadbalancer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |
| [aws_subnet_ids.shared-private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet_ids) | data source |
| [aws_vpc.shared](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_image_id"></a> [ami\_image\_id](#input\_ami\_image\_id) | EC2 AMI image to run in the ECS cluster | `string` | n/a | yes |
| <a name="input_app_count"></a> [app\_count](#input\_app\_count) | Number of docker containers to run | `string` | n/a | yes |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Name of the application | `string` | n/a | yes |
| <a name="input_container_cpu"></a> [container\_cpu](#input\_container\_cpu) | Container instance CPU units to provision (1 vCPU = 1024 CPU units) | `string` | n/a | yes |
| <a name="input_container_instance_type"></a> [container\_instance\_type](#input\_container\_instance\_type) | Container OS being used (windows or linux) | `string` | n/a | yes |
| <a name="input_container_memory"></a> [container\_memory](#input\_container\_memory) | Container instance memory to provision (in MiB) | `string` | n/a | yes |
| <a name="input_ec2_desired_capacity"></a> [ec2\_desired\_capacity](#input\_ec2\_desired\_capacity) | Number of EC2s in the cluster | `string` | n/a | yes |
| <a name="input_ec2_ingress_rules"></a> [ec2\_ingress\_rules](#input\_ec2\_ingress\_rules) | Security group ingress rules for the cluster EC2s | <pre>map(object({<br>    description     = string<br>    from_port       = number<br>    to_port         = number<br>    protocol        = string<br>    security_groups = list(string)<br>    cidr_blocks     = list(string)<br>  }))</pre> | n/a | yes |
| <a name="input_ec2_max_size"></a> [ec2\_max\_size](#input\_ec2\_max\_size) | Max Number of EC2s in the cluster | `string` | n/a | yes |
| <a name="input_ec2_min_size"></a> [ec2\_min\_size](#input\_ec2\_min\_size) | Min Number of EC2s in the cluster | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | The environment where resources are to be created (development, test, preprod, production) | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type to run in the ECS cluster | `string` | n/a | yes |
| <a name="input_key_name"></a> [key\_name](#input\_key\_name) | Key to access EC2s in ECS cluster | `string` | n/a | yes |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | The network mode used for the containers in the task. If OS used is Windows network\_mode must equal none. | `string` | n/a | yes |
| <a name="input_public_cidrs"></a> [public\_cidrs](#input\_public\_cidrs) | Public subnet CIDR blocks | `list(string)` | n/a | yes |
| <a name="input_server_port"></a> [server\_port](#input\_server\_port) | The port the containers will be listening on | `string` | n/a | yes |
| <a name="input_subnet_set_name"></a> [subnet\_set\_name](#input\_subnet\_set\_name) | The name of the subnet set associated with the account | `string` | n/a | yes |
| <a name="input_tags_common"></a> [tags\_common](#input\_tags\_common) | Common tags to be used by all resources | `map(string)` | n/a | yes |
| <a name="input_task_definition"></a> [task\_definition](#input\_task\_definition) | Task definition to be used by the ECS service | `string` | n/a | yes |
| <a name="input_task_definition_volume"></a> [task\_definition\_volume](#input\_task\_definition\_volume) | Name of the volume referenced in the sourceVolume parameter of container definition in the mountPoints section | `string` | n/a | yes |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | The configuration used when creating EC2s used for the ECS cluster | `string` | n/a | yes |
| <a name="input_vpc_all"></a> [vpc\_all](#input\_vpc\_all) | The full name of the VPC (including environment) used to create resources | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_ec2_security_group_id"></a> [cluster\_ec2\_security\_group\_id](#output\_cluster\_ec2\_security\_group\_id) | Security group id of EC2s used for ECS cluster |
| <a name="output_current_task_definition"></a> [current\_task\_definition](#output\_current\_task\_definition) | Displays task definition information and version being used |

<!--- END_TF_DOCS --->

## Looking for issues?
If you're looking to raise an issue with this module, please create a new issue in the [Modernisation Platform repository](https://github.com/ministryofjustice/modernisation-platform/issues).
