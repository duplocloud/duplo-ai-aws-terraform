terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.deployment.region

  default_tags {
    tags = merge(var.common_tags, {
      "duplocloud:deployment" = var.deployment.name
      "duplocloud:managed-by" = "cloud-deployment-agent"
    })
  }
}
