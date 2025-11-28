# ACM Certificate for arrow-dev.org
resource "aws_acm_certificate" "arrow_dev" {
  domain_name       = "conbench.arrow-dev.org"
  validation_method = "DNS"

  # Add wildcard subdomain if needed
  subject_alternative_names = ["*.arrow-dev.org"]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-arrow-dev-certificate"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Automatic DNS validation records for arrow-dev.org certificate
resource "aws_route53_record" "arrow_dev_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.arrow_dev.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.arrow_dev.zone_id
}

# Wait for arrow-dev.org certificate validation to complete
resource "aws_acm_certificate_validation" "arrow_dev" {
  certificate_arn         = aws_acm_certificate.arrow_dev.arn
  validation_record_fqdns = [for record in aws_route53_record.arrow_dev_cert_validation : record.fqdn]
}

# ACM Certificate for custom domains (if needed)
resource "aws_acm_certificate" "main" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  # Add wildcard subdomain if needed
  subject_alternative_names = var.include_wildcard_cert ? ["*.${var.domain_name}"] : []

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-certificate"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Automatic DNS validation records for custom domain
resource "aws_route53_record" "cert_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main[0].zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "main" {
  count                   = var.domain_name != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
