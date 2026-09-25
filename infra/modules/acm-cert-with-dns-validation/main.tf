# Manages an AWS ACM certificate and the necessary DNS records for its
# validation.  The certificate domain name and its subject alternative names
# must be valid within a single Route53 hosted zone, named by var.zone_name
# or, when that is not set, var.domain_name.

resource "aws_acm_certificate" "cert" {
  #checkov:skip=CKV2_AWS_71:we can't tell Checkov that domain_name won't include * here
  provider = aws.certificate

  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = var.subject_alternative_names

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "cert_domain" {
  name         = coalesce(var.zone_name, var.domain_name)
  private_zone = false
}

resource "aws_route53_record" "cert_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.cert_domain.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  provider = aws.certificate

  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_record : record.fqdn]
}

output "arn" {
  value = aws_acm_certificate_validation.cert_validation.certificate_arn
}
