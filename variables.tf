variable "additional_endpoints" {
  description = "additional endpoints required for VPC"
  type        = list(any)
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

variable "type" {
  description = "Type of Transit Gateway to attach to"
  type        = string

  validation {
    condition     = var.type == "live_data" || var.type == "non_live_data"
    error_message = "Accepted values are live_data, non_live_data."
  }
}

variable "vpc_flow_log_iam_role" {
  description = "VPC Flow Log IAM role ARN for VPC Flow Logs to CloudWatch"
  type        = string
}

variable "secondary_cidr_blocks" {
  description = "List of secondary CIDR blocks to associate with the VPC for additional subnet capacity"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.secondary_cidr_blocks :
      can(cidrhost(cidr, 0))
    ])
    error_message = "All secondary CIDR blocks must be valid CIDR notation (e.g., 10.27.160.0/21)."
  }

  validation {
    condition = length(var.secondary_cidr_blocks) == length(distinct(var.secondary_cidr_blocks))
    error_message = "Secondary CIDR blocks must not contain duplicates."
  }
}
