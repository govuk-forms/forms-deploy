resource "random_password" "cloudfront_secret" {
  length  = 32
  special = true
}

# The Certificate for CloudFront must be in us-east-1
module "acm_certificate_with_validation" {
  source = "../acm-cert-with-dns-validation"

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names

  providers = {
    aws             = aws
    aws.certificate = aws.us-east-1
  }
}

data "aws_cloudfront_response_headers_policy" "cors" {
  name = "Managed-SimpleCORS"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "cors_s3_origin" {
  name = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

module "cloudfront_waf_protection" {
  source                        = "../cloudfront_waf_protection"
  environment_name              = var.env_name
  ips_to_block                  = var.ips_to_block
  ip_rate_limit                 = var.ip_rate_limit
  nat_gateway_egress_ips        = var.nat_gateway_egress_ips
  send_logs_to_cyber            = var.send_logs_to_cyber
  rate_limit_bypass_cidrs       = var.rate_limit_bypass_cidrs
  kinesis_subscription_role_arn = var.kinesis_subscription_role_arn
  anti_ddos_exempt_uri_regular_expressions = [
    "^/up$",
    "^/api(/.*)?$",
  ]

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1 # Create the certificate in us-east-1 for CloudFront
  }
}

resource "aws_cloudfront_distribution" "main" {
  #checkov:skip=CKV_AWS_34:viewer_protocol_policy is already redirect-to-https
  #checkov:skip=CKV_AWS_86:Access logging not necessary currently.
  #checkov:skip=CKV2_AWS_32:Checkov error, response headers policy is set.
  #checkov:skip=CKV2_AWS_47:We don't use log4j
  #checkov:skip=CKV_AWS_310:We don't have a backup origin to fail over to
  #checkov:skip=CKV_AWS_374:We currently don't geo restrict

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "application_load_balancer"

    custom_origin_config {
      https_port             = 443
      http_port              = 80
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-CloudFront-Secret"
      value = random_password.cloudfront_secret.result
    }
  }

  origin {
    domain_name = module.error_page_bucket.website_url
    origin_id   = "error_page"

    custom_origin_config {
      https_port             = 443
      http_port              = 80
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name              = module.assets_bucket.regional_domain_name
    origin_id                = "assets_s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.assets.id
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "application_load_balancer"

    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors.id

    forwarded_values {
      cookies {
        forward = "all"
      }
      headers      = ["*"]
      query_string = true
    }
  }

  is_ipv6_enabled     = true
  http_version        = "http2and3"
  enabled             = true
  default_root_object = "/"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = module.acm_certificate_with_validation.arn
    minimum_protocol_version = "TLSv1.2_2019"
    ssl_support_method       = "sni-only"
  }

  aliases    = concat([var.domain_name], var.subject_alternative_names)
  web_acl_id = module.cloudfront_waf_protection.web_acl_arn

  custom_error_response {
    error_code         = 504
    response_page_path = "/cloudfront/error.html"
    response_code      = 200
  }

  ordered_cache_behavior {
    path_pattern             = "/cloudfront/*"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "error_page"
    viewer_protocol_policy   = "allow-all"
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors_s3_origin.id
  }

  # The applications can serve their own assets, but doing so causes
  # errors during deployments: old tasks cannot serve assets for a new
  # release. The assets bucket holds the assets for every release, so
  # prefer it once the deploy pipelines have started populating it.
  #
  # The all_viewer origin request policy must not be used with an S3
  # origin because forwarding the viewer Host header breaks the origin
  # access control request signing.
  ordered_cache_behavior {
    path_pattern           = "/assets/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.serve_assets_from_s3 ? "assets_s3" : "application_load_balancer"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = var.serve_assets_from_s3 ? data.aws_cloudfront_origin_request_policy.cors_s3_origin.id : data.aws_cloudfront_origin_request_policy.all_viewer.id
  }
}
