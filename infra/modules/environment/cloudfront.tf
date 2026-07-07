module "cloudfront" {
  count              = var.enable_cloudfront ? 1 : 0
  source             = "../cloudfront"
  send_logs_to_cyber = var.send_logs_to_cyber
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1 # Create the certificate in us-east-1 for CloudFront
  }

  env_name                = var.env_name
  domain_name             = "${local.domain_names[var.env_name]}forms.service.gov.uk"
  alb_dns_name            = aws_lb.alb.dns_name
  ip_rate_limit           = var.ip_rate_limit
  ips_to_block            = var.ips_to_block
  rate_limit_bypass_cidrs = var.rate_limit_bypass_cidrs
  nat_gateway_egress_ips = [
    aws_nat_gateway.nat_a.public_ip,
    aws_nat_gateway.nat_b.public_ip,
    aws_nat_gateway.nat_c.public_ip,
  ]

  subject_alternative_names     = local.subject_alternative_names[var.env_name]
  kinesis_subscription_role_arn = var.kinesis_subscription_role_arn

  serve_assets_from_s3 = var.serve_assets_from_s3
}

resource "aws_ssm_parameter" "email_zendesk" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  description = "Support email for GOV.UK Forms Zendesk"
  name        = "/alerting/email-zendesk"
  type        = "SecureString"
  value       = "not_a_real_email@digital.cabinet-office.gov.uk"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
