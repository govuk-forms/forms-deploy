resource "aws_route53_record" "ses" {
  count   = 3
  zone_id = var.hosted_zone_id
  name    = "${aws_ses_domain_dkim.ses.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.ses.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "ses_domain_verification" {
  zone_id = var.hosted_zone_id
  name    = "_amazonses.${aws_ses_domain_identity.ses.domain}"
  type    = "TXT"
  ttl     = 60
  records = [aws_ses_domain_identity.ses.verification_token]
}

resource "aws_ses_domain_identity_verification" "ses" {
  domain = aws_ses_domain_identity.ses.id

  depends_on = [aws_route53_record.ses_domain_verification]
}

resource "aws_route53_record" "ses_email_receiving" {
  zone_id = var.hosted_zone_id
  name    = aws_ses_domain_identity.ses.domain
  type    = "MX"
  records = ["10 inbound-smtp.eu-west-2.amazonaws.com"]
  ttl     = 3600
}

resource "aws_route53_record" "ses_feedback" {
  zone_id = var.hosted_zone_id
  name    = "mail.${aws_ses_domain_identity.ses.domain}"
  type    = "MX"
  records = ["10 feedback-smtp.eu-west-2.amazonses.com"]
  ttl     = 3600
}
