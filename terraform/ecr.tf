# ECR Repositories
# This file defines ECR repositories for Docker images

# ECR Repository for Conbench
resource "aws_ecr_repository" "conbench" {
  name                 = "conbench"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "conbench"
    Environment = var.environment
  }
}

# ECR Repository for Arrow BCI
resource "aws_ecr_repository" "arrow_bci" {
  name                 = "arrow-bci"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "arrow-bci"
    Environment = var.environment
  }
}

# Lifecycle policy for Conbench - keep last 10 images
resource "aws_ecr_lifecycle_policy" "conbench" {
  repository = aws_ecr_repository.conbench.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Lifecycle policy for Arrow BCI - keep last 10 images
resource "aws_ecr_lifecycle_policy" "arrow_bci" {
  repository = aws_ecr_repository.arrow_bci.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
