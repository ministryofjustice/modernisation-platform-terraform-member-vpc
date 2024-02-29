variable "subnet_sets" {
  type = map(any)
}

variable "tags_common" {
  description = "MOJ required tags"
  type        = map(string)
}

variable "tags_prefix" {
  description = "prefix for name tags"
  type        = string
}

variable "transit_gateway_id" {
  description = "tgw ID"
  type        = string
}

variable "additional_endpoints" {
  description = "additional endpoints required for VPC"
  type        = list(any)
}

variable "vpc_flow_log_iam_role" {
  description = "VPC Flow Log IAM role ARN for VPC Flow Logs to CloudWatch"
  type        = string
}

variable "build_firehose" {
  description = "boolean for whether AWS Firehose resources are built in the environment"
  type        = bool
}

variable "environment" {
  description = "The name of the environment e.g. development, test etc"
  type        = string
}

variable "endpoint_url" {
  description = "The aws kenisis http endpoint that the log data will be sent to"
  type        = string
}

variable "secret_version_arn" {
  description = "The arn of the secret version that contains the endpoint key"
  type        = string
}