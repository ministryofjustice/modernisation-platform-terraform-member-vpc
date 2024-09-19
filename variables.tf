variable "additional_endpoints" {
  description = "additional endpoints required for VPC"
  type        = list(any)
}

variable "build_firehose" {
  description = "Whether we want to build the firehose resources in the environment or not"
  type        = bool
}

variable "flow_log_s3_destination_arn" {
  description = "Optionally supply an ARN of an S3 bucket to send flow logs to"
  default     = ""
  type        = string
}

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

variable "vpc_flow_log_iam_role" {
  description = "VPC Flow Log IAM role ARN for VPC Flow Logs to CloudWatch"
  type        = string
}

# Both of the following variables are required for the firehose resources to build.

variable "kinesis_endpoint_url" {
  description = "The aws kinesis http endpoint that the log data will be sent to"
  type        = string
}

variable "kinesis_endpoint_secret_string" {
  description = "The secret that contains the endpoint key"
  type        = string
}