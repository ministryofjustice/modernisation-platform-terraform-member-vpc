terraform {
  required_providers {
    aws = {
      version = "~> 6.0"
      source  = "hashicorp/aws"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
  }
  required_version = "~> 1.0"
}
