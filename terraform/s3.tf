
resource "aws_s3_bucket" "buildkite_secrets" {
  bucket = var.buildkite_secrets_bucket
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buildkite_secrets" {
  bucket = aws_s3_bucket.buildkite_secrets.id

  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "buildkite_secrets" {
  bucket = aws_s3_bucket.buildkite_secrets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// This disables ACLs, as is now recommended.
resource "aws_s3_bucket_ownership_controls" "buildkite_secrets" {
  bucket = aws_s3_bucket.buildkite_secrets.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Upload benchmark pipeline secrets
locals {
  benchmark_machines = [
    "amd64-c6a-4xlarge-linux",
    "amd64-m5-4xlarge-linux",
    "arm64-t4g-2xlarge-linux",
  ]

  # # Map of pipeline names to their secret file paths
  # pipeline_secrets = {
  #   "arrow-bci-deploy"                = "secrets/arrow-bci-deploy/env"
  #   "arrow-bci-schedule-and-publish"  = "secrets/arrow-bci-schedule-and-publish/env"
  #   "arrow-bci-benchmark-build-test"  = "secrets/arrow-bci-benchmark-build-test/env"
  #   "conbench-deploy"                 = "secrets/conbench-deploy/env"
  #   "conbench-rollback"               = "secrets/conbench-rollback/env"
  # }
}

# Upload benchmark machine secrets
resource "aws_s3_object" "benchmark_machine_secrets" {
  for_each = toset(local.benchmark_machines)

  bucket = aws_s3_bucket.buildkite_secrets.id
  key = "arrow-bci-benchmark-on-${each.value}/env"
  source = "${path.module}/buildkite_secrets/arrow-bci-benchmark-on-${each.value}/env"
  etag = filemd5("${path.module}/buildkite_secrets/arrow-bci-benchmark-on-${each.value}/env")
  tags = local.common_tags
}

# Upload benchmark machine secrets
resource "aws_s3_object" "benchmark_machine_secrets2" {
  bucket = aws_s3_bucket.buildkite_secrets.id
  key = "new-arrow-bci-schedule-and-publish/env"
  source = "${path.module}/buildkite_secrets/new-arrow-bci-schedule-and-publish/env"
  etag = filemd5("${path.module}/buildkite_secrets/new-arrow-bci-schedule-and-publish/env")
  tags = local.common_tags
}

# # Upload pipeline secrets
# resource "aws_s3_object" "pipeline_secrets" {
#   for_each = local.pipeline_secrets
#
#   bucket = aws_s3_bucket.buildkite_secrets.id
#   key = "${each.key}/env"
#   source = "${path.module}/buildkite_secrets/${each.value}"
#   etag = filemd5("${path.module}/buildkite_secrets/${each.value}")
#
#   tags = local.common_tags
# }