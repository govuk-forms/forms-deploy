locals {
  test_mail_bucket_name = "govuk-forms-${replace(lower(var.environment_name), "_", "-")}-test-emails"
  test_mail_receipt_rule_source_arn = "arn:${data.aws_partition.current.partition}:ses:${data.aws_region.current.name}:${local.aws_account_id}:receipt-rule-set/${aws_ses_receipt_rule_set.test_mail.rule_set_name}:receipt-rule/*"
}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "test_mail_bucket" {
  statement {
    sid       = "AllowSesInboundEmailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.test_mail_bucket_name}/*"]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.aws_account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.test_mail_receipt_rule_source_arn]
    }
  }
}

module "test_mail_bucket" {
  source = "../secure-bucket"

  name                   = local.test_mail_bucket_name
  versioning_enabled     = false
  access_logging_enabled = false
  extra_bucket_policies = [
    data.aws_iam_policy_document.test_mail_bucket.json
  ]
}

resource "aws_s3_bucket_lifecycle_configuration" "test_mail_bucket" {
  bucket = module.test_mail_bucket.name

  rule {
    id     = "expire-test-emails"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_ses_receipt_rule_set" "test_mail" {
  rule_set_name = "test-mail"
}

resource "aws_ses_active_receipt_rule_set" "test_mail" {
  rule_set_name = aws_ses_receipt_rule_set.test_mail.rule_set_name
}

resource "aws_ses_receipt_rule" "test_confirmation_emails_to_s3" {
  name          = "test-confirmation-emails-to-s3"
  rule_set_name = aws_ses_receipt_rule_set.test_mail.rule_set_name
  enabled       = true
  scan_enabled  = true
  recipients    = ["confirmation-email-tests@${var.email_domain}"]
  tls_policy    = "Require"

  s3_action {
    bucket_name       = module.test_mail_bucket.name
    object_key_prefix = "confirmation-emails/"
    position          = 1
  }

  depends_on = [module.test_mail_bucket]
}

resource "aws_ses_receipt_rule" "test_copy_of_answers_emails_to_s3" {
  name          = "test-copy-of-answers-emails-to-s3"
  rule_set_name = aws_ses_receipt_rule_set.test_mail.rule_set_name
  enabled       = true
  scan_enabled  = true
  recipients    = ["copy-of-answers-emails-tests@${var.email_domain}"]
  tls_policy    = "Require"

  s3_action {
    bucket_name       = module.test_mail_bucket.name
    object_key_prefix = "copy-of-answers-emails/"
    position          = 1
  }

  depends_on = [module.test_mail_bucket]
}

resource "aws_ses_receipt_rule" "test_submission_emails_to_s3" {
  name          = "test-submission-emails-to-s3"
  rule_set_name = aws_ses_receipt_rule_set.test_mail.rule_set_name
  enabled       = true
  scan_enabled  = true
  recipients    = ["submissions-tests@${var.email_domain}"]
  tls_policy    = "Require"

  s3_action {
    bucket_name       = module.test_mail_bucket.name
    object_key_prefix = "submissions/"
    position          = 1
  }

  depends_on = [module.test_mail_bucket]
}
