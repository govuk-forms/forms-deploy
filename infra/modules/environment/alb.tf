data "aws_caller_identity" "current" {}

locals {
  # domain_names and zone_names can be combined after the migration.
  # Used to lookup the domain name for the ALB record and certificate.
  domain_names = {
    dev        = "dev."
    staging    = "staging.",
    production = ""
  }

  subject_alternative_names = {
    dev = [
      "admin.dev.forms.service.gov.uk",
      "submit.dev.forms.service.gov.uk",
      "www.dev.forms.service.gov.uk",
    ],
    staging = [
      "admin.staging.forms.service.gov.uk",
      "submit.staging.forms.service.gov.uk",
      "www.staging.forms.service.gov.uk",
    ],
    production = [
      "admin.forms.service.gov.uk",
      "submit.forms.service.gov.uk",
      "www.forms.service.gov.uk",
    ]
  }

  account_id = data.aws_caller_identity.current.account_id

  #The AWS managed account for the ALB, see: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
  aws_lb_account_id = "652711504416"
}

module "logs_bucket" {
  source = "../access-logs-bucket"

  bucket_name               = "govuk-forms-alb-logs-${var.env_name}"
  send_access_logs_to_cyber = var.send_logs_to_cyber
  extra_bucket_policies     = [data.aws_iam_policy_document.allow_logs.json]
}

data "aws_iam_policy_document" "allow_logs" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.aws_lb_account_id}:root"]
    }
    actions = ["s3:PutObject"]
    resources = [
      "arn:aws:s3:::${module.logs_bucket.bucket_name}/${var.env_name}/AWSLogs/${local.account_id}/*",
      "arn:aws:s3:::${module.logs_bucket.bucket_name}/forms-internal/AWSLogs/${local.account_id}/*"
    ]
  }
}

resource "aws_lb" "alb" {
  #checkov:skip=CKV2_AWS_28:WAF is not considered necessary at this time.

  name                       = "forms-${var.env_name}"
  internal                   = false
  load_balancer_type         = "application"
  enable_deletion_protection = true
  drop_invalid_header_fields = true
  security_groups            = [aws_security_group.alb.id]
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
    aws_subnet.public_c.id
  ]

  access_logs {
    bucket  = module.logs_bucket.bucket_name
    prefix  = var.env_name
    enabled = true
  }
}

resource "aws_security_group" "alb" {
  name        = "alb-${var.env_name}"
  description = "Allows public inbound on 443 and outbound to VPC"
  vpc_id      = aws_vpc.forms.id

  ingress {
    description = "Port 443 from public"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Any port within VPC using TCP"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.forms.cidr_block]
  }
}

# Internal ALB for app-to-app communication
resource "aws_lb" "internal_alb" {
  #checkov:skip=CKV2_AWS_28:WAF is not considered necessary at this time.
  #checkov:skip=CKV2_AWS_20:HTTP to HTTPS redirect not required for internal service-to-service communication

  name                       = "forms-internal"
  internal                   = true
  load_balancer_type         = "application"
  enable_deletion_protection = true
  drop_invalid_header_fields = true
  security_groups            = [aws_security_group.internal_alb.id]

  subnets = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]

  access_logs {
    bucket  = module.logs_bucket.bucket_name
    prefix  = "forms-internal"
    enabled = true
  }
}

resource "aws_security_group" "internal_alb" {
  name        = "internal-alb"
  description = "Allows internal traffic on 80 and outbound to VPC"
  vpc_id      = aws_vpc.forms.id

  ingress {
    description = "Port 80 from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.forms.cidr_block]
  }

  egress {
    description = "Any port within VPC using TCP"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.forms.cidr_block]
  }
}

module "acm_certicate_with_validation" {
  source = "../acm-cert-with-dns-validation"
  providers = {
    aws             = aws
    aws.certificate = aws # Create the certificate in the default eu-west-2
  }

  domain_name               = var.root_domain
  subject_alternative_names = local.subject_alternative_names[var.env_name]
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = module.acm_certicate_with_validation.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Access denied"
      status_code  = 403
    }
  }
}

resource "aws_lb_listener" "internal_listener" {
  #checkov:skip=CKV_AWS_2:HTTP listener is used for internal service-to-service communication within VPC
  #checkov:skip=CKV_AWS_103:TLS not required for internal HTTP listener used for service-to-service communication

  load_balancer_arn = aws_lb.internal_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Service unavailable"
      status_code  = 503
    }
  }
}

# This listener exists to facilitate future cloudfront to ALB HTTPS communication.
resource "aws_lb_listener" "internal_https_listener" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = module.acm_certicate_with_validation.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Service unavailable"
      status_code  = 503
    }
  }
}
