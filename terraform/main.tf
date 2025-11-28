terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    buildkite = {
      source  = "buildkite/buildkite"
      version = "~> 1.0"
    }
  }

  # Optional: Configure backend for state storage
  backend "s3" {
    bucket = "arrow-terraform-state"
    key    = "conbench/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project     = "conbench"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Provider for Kubernetes resources (configured after EKS cluster is created)
provider "kubernetes" {
  host                   = aws_eks_cluster.conbench.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.conbench.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      ["eks", "get-token", "--cluster-name", aws_eks_cluster.conbench.name, "--region", var.aws_region],
      var.aws_profile != "" ? ["--profile", var.aws_profile] : []
    )
  }
}

# Provider for Buildkite (for managing pipelines and teams)
provider "buildkite" {
  api_token    = var.buildkite_api_token
  organization = var.buildkite_org
}

# Get AWS account ID for resource naming
data "aws_caller_identity" "current" {}

locals {
  cluster_name = "conbench-${var.environment}"

  common_tags = {
    Project     = "conbench"
    Environment = var.environment
  }
}
