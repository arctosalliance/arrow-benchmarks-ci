resource "aws_ssm_parameter" "buildkite_agent_token" {
  name        = "/buildkite/agent-token-benchmark-machines"
  description = "Buildkite Agent Token for benchmark machines"
  type        = "SecureString"
  value       = buildkite_agent_token.token_for_agents_in_arrow_computing_aws.token
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "buildkite_api_base_url" {
  name        = "/buildkite/config/api-base-url"
  description = "Buildkite API Base URL"
  type        = "String"
  value       = var.buildkite_api_base_url
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "buildkite_org" {
  name        = "/buildkite/config/org"
  description = "Buildkite Organization"
  type        = "String"
  value       = var.buildkite_org
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "conbench_url" {
  name        = "/buildkite/config/conbench-url"
  description = "Conbench URL"
  type        = "String"
  value       = var.conbench_url
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "db_port" {
  name        = "/buildkite/config/db-port"
  description = "Database Port"
  type        = "String"
  value       = var.db_port
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "env" {
  name        = "/buildkite/config/env"
  description = "Environment (prod/staging/dev)"
  type        = "String"
  value       = var.environment
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "flask_app" {
  name        = "/buildkite/config/flask-app"
  description = "Flask Application Name"
  type        = "String"
  value       = var.flask_app
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "github_api_base_url" {
  name        = "/buildkite/config/github-api-base-url"
  description = "GitHub API Base URL"
  type        = "String"
  value       = var.github_api_base_url
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "github_repo" {
  name        = "/buildkite/config/github-repo"
  description = "GitHub Repository"
  type        = "String"
  value       = var.github_repo
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "github_repo_with_benchmarkable_commits" {
  name        = "/buildkite/config/github-repo-benchmarkable"
  description = "GitHub Repository with Benchmarkable Commits"
  type        = "String"
  value       = var.github_repo_with_benchmarkable_commits
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "max_commits_to_fetch" {
  name        = "/buildkite/config/max-commits-to-fetch"
  description = "Maximum Commits to Fetch"
  type        = "String"
  value       = var.max_commits_to_fetch
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "pypi_api_base_url" {
  name        = "/buildkite/config/pypi-api-base-url"
  description = "PyPI API Base URL"
  type        = "String"
  value       = var.pypi_api_base_url
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "pypi_project" {
  name        = "/buildkite/config/pypi-project"
  description = "PyPI Project Name"
  type        = "String"
  value       = var.pypi_project
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "slack_api_base_url" {
  name        = "/buildkite/config/slack-api-base-url"
  description = "Slack API Base URL"
  type        = "String"
  value       = var.slack_api_base_url
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "docker_registry" {
  name        = "/buildkite/config/docker-registry"
  description = "Docker Registry URL (ECR)"
  type        = "String"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  tags        = local.common_tags
}

# IAM policy for Buildkite agents
resource "aws_iam_policy" "buildkite_agent" {
  name        = "${local.cluster_name}-buildkite-agent-policy"
  description = "IAM policy for Buildkite agents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/buildkite/*"
      }
    ]
  })

  tags = local.common_tags
}

# data "aws_iam_policy" "buildkite_agent" {
#   name = join(",", [
#       aws_iam_policy.buildkite_agent.arn,
#       "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#     ])
# }

resource "aws_cloudformation_stack" "conbench" {
  name = "new-conbench"
  parameters = {
    VpcId                                 = aws_vpc.main.id
    Subnets                               = join(",", [aws_subnet.public[0].id, aws_subnet.public[1].id])
    BuildkiteAgentTokenParameterStorePath = aws_ssm_parameter.buildkite_agent_token.name
    BuildkiteQueue                        = "new-conbench"
    # Image built on this same folder, packer subfolder
    # ImageId                               = "ami-0f366f62f5c4cd839"
    # InstanceType                          = "t3.micro"
    InstanceOperatingSystem               = "linux"
    InstanceRoleName                      = "buildkite-agent-stack-conbench-Role"
    # ManagedPolicyARN                      = join(",", [aws_iam_policy.buildkite_agent.arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"])
    AgentsPerInstance                     = 1
    ECRAccessPolicy                       = "full"
    MinSize                               = 0
    MaxSize                               = 2
    # SecretsBucket                         = "${var.buildkite_org}-buildkite-secrets"
  }
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_AUTO_EXPAND"
  ]
  # template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v5.22.5/aws-stack.yml"
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v6.22.3/aws-stack.yml"
  tags         = merge(var.default_tags, { "service" : "conbench" })
}

resource "aws_cloudformation_stack" "arrow-bci" {
  name = "new-arrow-bci"
  parameters = {
    VpcId                                 = aws_vpc.main.id
    Subnets                               = join(",", [aws_subnet.public[0].id, aws_subnet.public[1].id])
    # BootstrapScriptUrl                    = "s3://ursa-benchmarks/bootstrap_script_arrow_benchmarks_ci.sh"
    BootstrapScriptUrl                    = var.buildkite_bootstrap_script_url
    BuildkiteAgentTokenParameterStorePath = aws_ssm_parameter.buildkite_agent_token.name
    BuildkiteQueue                        = "new-arrow-bci"
    # InstanceType                          = "t3.micro"
    InstanceOperatingSystem               = "linux"
    InstanceRoleName                      = "buildkite-agent-stack-arrow-bci-Role"
    # ManagedPolicyARN                      = join(",", [aws_iam_policy.buildkite_agent.arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"])
    AgentsPerInstance                     = 1
    ECRAccessPolicy                       = "full"
    MinSize                               = 0
    MaxSize                               = 10
    # SecretsBucket                         = "${var.buildkite_org}-buildkite-secrets"
  }
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_AUTO_EXPAND"
  ]
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v6.22.3/aws-stack.yml"
  tags         = merge(var.default_tags, { "service" : "arrow-bci" })
}

resource "aws_cloudformation_stack" "arrow-bci-test" {
  name = "new-arrow-bci-test"
  parameters = {
    VpcId                                 = aws_vpc.main.id
    Subnets                               = join(",", [aws_subnet.public[0].id, aws_subnet.public[1].id])
    BuildkiteAgentTokenParameterStorePath = aws_ssm_parameter.buildkite_agent_token.name
    BuildkiteQueue                        = "new-arrow-bci-test"
    # InstanceType                          = "t3.micro"
    InstanceOperatingSystem               = "linux"
    # ManagedPolicyARN                      = join(",", [aws_iam_policy.buildkite_agent.arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"])
    AgentsPerInstance                     = 1
    ECRAccessPolicy                       = "full"
    MinSize                               = 0
    MaxSize                               = 10
    # SecretsBucket                         = "${var.buildkite_org}-buildkite-secrets"
  }
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_AUTO_EXPAND"
  ]
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v6.22.3/aws-stack.yml"
  tags         = merge(var.default_tags, { "service" : "arrow-bci" })
}

resource "aws_cloudformation_stack" "arrow-bci-benchmark-build-test" {
  name = "new-arrow-bci-benchmark-build-test"
  parameters = {
    VpcId                                 = aws_vpc.main.id
    Subnets                               = join(",", [aws_subnet.public[0].id, aws_subnet.public[1].id])
    BuildkiteAgentTokenParameterStorePath = aws_ssm_parameter.buildkite_agent_token.name
    BuildkiteQueue                        = "new-arrow-bci-benchmark-build-test"
    # InstanceType                          = "r5.4xlarge"
    InstanceOperatingSystem               = "linux"
    # ManagedPolicyARN                      = join(",", [aws_iam_policy.buildkite_agent.arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"])
    AgentsPerInstance                     = 1
    ECRAccessPolicy                       = "full"
    MinSize                               = 0
    MaxSize                               = 10
    # SecretsBucket                         = "${var.buildkite_org}-buildkite-secrets"
  }
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_AUTO_EXPAND"
  ]
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v6.22.3/aws-stack.yml"
  tags         = merge(var.default_tags, { "service" : "arrow-bci" })
}


resource "aws_cloudformation_stack" "arm64-t4g-2xlarge-linux" {
  name = "new-arm64-t4g-2xlarge-linux"
  parameters = {
    VpcId                                 = aws_vpc.main.id
    Subnets                               = join(",", [aws_subnet.public[0].id, aws_subnet.public[1].id])
    BootstrapScriptUrl                    = var.buildkite_bootstrap_script_url
    BuildkiteAgentTokenParameterStorePath = aws_ssm_parameter.buildkite_agent_token.name
    BuildkiteQueue                        = "new-arm64-t4g-2xlarge-linux"
    OnDemandPercentage                    = 100
    InstanceTypes                         = "t4g.2xlarge"
    InstanceOperatingSystem               = "linux"
    # ManagedPolicyARNs                     = join(",", [data.aws_iam_policy.buildkite_agent.arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"])
    ManagedPolicyARNs                     = join(",", [aws_iam_policy.buildkite_agent.arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"])
    AgentsPerInstance                     = 1
    ECRAccessPolicy                       = "full"
    MinSize                               = 0
    MaxSize                               = 2
    # SecretsBucket                         = "${var.buildkite_org}-buildkite-secrets"
  }
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_AUTO_EXPAND"
  ]
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v6.22.3/aws-stack.yml"
  tags         = var.default_tags
}

resource "aws_cloudformation_stack" "amd64-m5-4xlarge-linux" {
  name = "new-amd64-m5-4xlarge-linux"
  parameters = {
    VpcId                                 = aws_vpc.main.id
    Subnets                               = join(",", [aws_subnet.public[0].id, aws_subnet.public[1].id])
    BootstrapScriptUrl                    = var.buildkite_bootstrap_script_url
    # BootstrapScriptUrl                    = join("", ["s3://", aws_s3_bucket.buildkite_scripts.id, "/", aws_s3_object.setup_script.key])
    BuildkiteAgentTokenParameterStorePath = aws_ssm_parameter.buildkite_agent_token.name
    BuildkiteQueue                        = "new-amd64-m5-4xlarge-linux"
    OnDemandPercentage                    = 100
    InstanceTypes                         = "m5.4xlarge"
    InstanceOperatingSystem               = "linux"
    ManagedPolicyARNs                     = join(",", [aws_iam_policy.buildkite_agent.arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"])
    AgentsPerInstance                     = 1
    ECRAccessPolicy                       = "full"
    MinSize                               = 0
    MaxSize                               = 10
    # SecretsBucket                         = "${var.buildkite_org}-buildkite-secrets"
  }
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_AUTO_EXPAND"
  ]
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v6.22.3/aws-stack.yml"
  tags         = var.default_tags
}

resource "aws_cloudformation_stack" "amd64-c6a-4xlarge-linux" {
  name = "new-amd64-c6a-4xlarge-linux"
  parameters = {
    VpcId                                 = aws_vpc.main.id
    Subnets                               = join(",", [aws_subnet.public[0].id, aws_subnet.public[1].id])
    BootstrapScriptUrl                    = var.buildkite_bootstrap_script_url
    # BootstrapScriptUrl                    = join("", ["s3://", aws_s3_bucket.buildkite_scripts.id, "/", aws_s3_object.setup_script.key])
    BuildkiteAgentTokenParameterStorePath = aws_ssm_parameter.buildkite_agent_token.name
    BuildkiteQueue                        = "new-amd64-c6a-4xlarge-linux"
    OnDemandPercentage                    = 100
    InstanceTypes                         = "c6a.4xlarge"
    InstanceOperatingSystem               = "linux"
    ManagedPolicyARNs                     = join(",", [aws_iam_policy.buildkite_agent.arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"])
    AgentsPerInstance                     = 1
    ECRAccessPolicy                       = "full"
    MinSize                               = 0
    MaxSize                               = 10
    # SecretsBucket                         = "${var.buildkite_org}-buildkite-secrets"
  }
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_AUTO_EXPAND"
  ]
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v6.22.3/aws-stack.yml"
  tags         = var.default_tags
}
