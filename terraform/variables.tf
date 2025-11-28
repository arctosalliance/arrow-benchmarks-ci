# General Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the EKS cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# EKS Variables
variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
}

# RDS Variables
variable "db_snapshot_identifier" {
  description = "RDS snapshot identifier to restore from (leave empty to create new instance)"
  type        = string
  default     = ""
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.5"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB (not used if restoring from snapshot)"
  type        = number
  default     = 100
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage in GB for autoscaling"
  type        = number
  default     = 500
}

variable "db_name" {
  description = "Database name (only used for new instances, not snapshots)"
  type        = string
  default     = "conbench"
}

variable "db_username" {
  description = "Master username (only used for new instances, not snapshots)"
  type        = string
  default     = "conbench_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password (only used for new instances, not snapshots)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.db_password == "" || length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for high availability"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying the database"
  type        = bool
  default     = false
}

variable "db_apply_immediately" {
  description = "Apply changes immediately (vs during maintenance window)"
  type        = bool
  default     = false
}

# Domain and DNS Variables
variable "domain_name" {
  description = "Domain name for the application (e.g., yourdomain.com)"
  type        = string
  default     = ""
}

variable "include_wildcard_cert" {
  description = "Include wildcard subdomain (*.domain.com) in ACM certificate"
  type        = bool
  default     = true
}

variable "create_route53_record" {
  description = "Create Route53 A record for ALB (set to false initially, update after ALB is created)"
  type        = bool
  default     = false
}

variable "create_www_record" {
  description = "Create www subdomain CNAME record"
  type        = bool
  default     = false
}

variable "create_crossbow_subdomain" {
  description = "Create crossbow subdomain with CloudFront + S3"
  type        = bool
  default     = false
}

variable "alb_dns_name" {
  description = "ALB DNS name (get this after ingress creates the ALB)"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID (get this after ingress creates the ALB)"
  type        = string
  default     = ""
}

# ELB Variables (for conbench.arrow-dev.org)
variable "elb_dns_name" {
  description = "ELB DNS name for conbench endpoint"
  type        = string
  default     = "a1124e533393c450ea143b5d49b7f373-1467638017.us-east-1.elb.amazonaws.com"
}

variable "elb_zone_id" {
  description = "ELB hosted zone ID for conbench endpoint"
  type        = string
  default     = "Z35SXDOTRQ7X7K"
}

# Buildkite Variables
variable "buildkite_agent_token" {
  description = "Buildkite agent token for authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "buildkite_api_token" {
  description = "Buildkite API token for managing pipelines and agent tokens (get from https://buildkite.com/user/api-access-tokens - requires scopes: graphql, read_pipelines, write_pipelines, read_organizations)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "buildkite_org" {
  description = "Buildkite organization slug"
  type        = string
  default     = "apache-arrow"
}

# Pipeline Configuration Variables
variable "buildkite_api_base_url" {
  description = "Buildkite API base URL"
  type        = string
  default     = "https://api.buildkite.com/v2"
}

variable "conbench_url" {
  description = "Conbench application URL"
  type        = string
  default     = "https://conbench.arrow-dev.org"
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "5432"
}

variable "flask_app" {
  description = "Flask application name"
  type        = string
  default     = "conbench"
}

variable "github_api_base_url" {
  description = "GitHub API base URL"
  type        = string
  default     = "https://api.github.com"
}

variable "github_repo" {
  description = "GitHub repository (format: owner/repo)"
  type        = string
  default     = "apache/arrow"
}

variable "github_repo_with_benchmarkable_commits" {
  description = "GitHub repository with benchmarkable commits"
  type        = string
  default     = "apache/arrow"
}

variable "max_commits_to_fetch" {
  description = "Maximum number of commits to fetch"
  type        = string
  default     = "100"
}

variable "pypi_api_base_url" {
  description = "PyPI API base URL"
  type        = string
  default     = "https://pypi.org/pypi"
}

variable "pypi_project" {
  description = "PyPI project name"
  type        = string
  default     = "pyarrow"
}

variable "slack_api_base_url" {
  description = "Slack API base URL"
  type        = string
  default     = "https://slack.com/api"
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    # "environment"     = "production"
    "team"            = "benchmarking"
    "owner"           = "benchmarking"
    "no_delete"       = "true"
    "creation_method" = "terraform_arrow_infra"
  }
}

variable "buildkite_bootstrap_script_url" {
    description = "URL of the Buildkite agent bootstrap script"
    type        = string
    default     = "https://raw.githubusercontent.com/rok/conbench/refs/heads/main/terraform/buildkite-bootstrap.sh"
}

# variable "buildkite_agent_amis" {
#   description = "AMI IDs for Buildkite agents by platform"
#   type        = map(string)
#   default = {
#     # Amazon Linux 2023 AMIs (update these periodically)
#     # AMD64 (x86_64)
#     "amd64-linux" = "ami-0453ec754f44f9a4a" # Amazon Linux 2023 AMD64 us-east-1
#     # ARM64 (aarch64)
#     "arm64-linux" = "ami-0c101f26f147fa7fd" # Amazon Linux 2023 ARM64 us-east-1
#     # macOS Tahoe
#     "amd64-macos" = "ami-0ef51d32f7d6e780d" # macOS Tahoe 26.x us-east-1
#   }
# }
