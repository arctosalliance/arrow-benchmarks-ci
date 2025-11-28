# CloudFront Distribution for crossbow.arrow-dev.org
# Serves content from arrow-data S3 bucket with HTTPS

resource "aws_cloudfront_distribution" "crossbow" {
  count   = var.create_crossbow_subdomain ? 1 : 0
  enabled = true
  aliases = ["crossbow.arrow-dev.org"]

  # S3 Origin - arrow-data bucket
  origin {
    domain_name = "arrow-data.s3.amazonaws.com"
    origin_id   = "S3-arrow-data"
  }

  # Cache behavior
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-arrow-data"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # SSL Certificate
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.arrow_dev.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # No geo restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  tags = merge(
    local.common_tags,
    {
      Name = "crossbow-cloudfront"
    }
  )

  depends_on = [aws_acm_certificate_validation.arrow_dev]
}

# Route53 record for crossbow subdomain
resource "aws_route53_record" "crossbow" {
  count   = var.create_crossbow_subdomain ? 1 : 0
  zone_id = data.aws_route53_zone.arrow_dev.zone_id
  name    = "crossbow.arrow-dev.org"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.crossbow[0].domain_name
    zone_id                = aws_cloudfront_distribution.crossbow[0].hosted_zone_id
    evaluate_target_health = false
  }
}
