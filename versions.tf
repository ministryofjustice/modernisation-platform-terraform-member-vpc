terraform {
  required_providers {
    aws = {
      version               = "~> 5.0"
      source                = "hashicorp/aws"
      configuration_aliases = [aws.transit-gateway-host]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
  required_version = ">= 1.0.1"
}