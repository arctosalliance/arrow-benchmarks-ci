# Reference existing arrow-dev.org hosted zone
data "aws_route53_zone" "arrow_dev" {
  name         = "arrow-dev.org"
  private_zone = false
}

# Route53 Hosted Zone (for custom domains if needed)
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-hosted-zone"
    }
  )
}

# A Record for conbench.arrow-dev.org pointing to EKS ELB
resource "aws_route53_record" "conbench" {
  zone_id = data.aws_route53_zone.arrow_dev.zone_id
  name    = "conbench.arrow-dev.org"
  type    = "A"

  alias {
    name                   = var.elb_dns_name
    zone_id                = var.elb_zone_id
    evaluate_target_health = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# A Record for ALB (points to the load balancer) - for custom domains
resource "aws_route53_record" "app" {
  count   = var.create_route53_record ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Optional: WWW subdomain redirect - for custom domains
resource "aws_route53_record" "www" {
  count   = var.create_www_record ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain_name]
}
