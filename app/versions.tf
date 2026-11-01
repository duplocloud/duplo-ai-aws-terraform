terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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

# Kubernetes access without an exec plugin: the endpoint and CA come from the
# platform root's state, the token from the EKS auth API.
provider "helm" {
  kubernetes {
    host                   = local.platform.cluster_endpoint
    cluster_ca_certificate = base64decode(local.platform.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = local.platform.cluster_endpoint
  cluster_ca_certificate = base64decode(local.platform.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}
