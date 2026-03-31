locals {
  test_mail_bucket_name = "forms-${replace(lower(var.environment_name), "_", "-")}-test-emails"
}

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
      variable = "aws:Referer"
      values   = [local.aws_account_id]
    }
  }
}

resource "aws_s3_bucket" "test_mail_bucket" {
  #checkov:skip=CKV2_AWS_62:No event notifications are needed for this temporary test email bucket
  #checkov:skip=CKV_AWS_145:Amazon managed S3 encryption is sufficient for temporary test emails
  #checkov:skip=CKV_AWS_18:Access logging is not needed for this temporary test email bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication is not needed for temporary test emails
  #checkov:skip=CKV2_AWS_6:Public access is controlled by the bucket policy for SES writes only
  #checkov:skip=CKV_AWS_21:Versioning is not needed for temporary test emails that expire after 7 days
  bucket = local.test_mail_bucket_name
}

resource "aws_s3_bucket_policy" "test_mail_bucket" {
  bucket = aws_s3_bucket.test_mail_bucket.id
  policy = data.aws_iam_policy_document.test_mail_bucket.json
}

resource "aws_s3_bucket_lifecycle_configuration" "test_mail_bucket" {
  bucket = aws_s3_bucket.test_mail_bucket.id

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
    bucket_name       = aws_s3_bucket.test_mail_bucket.id
    object_key_prefix = "confirmation-emails/"
    position          = 1
  }

  depends_on = [aws_s3_bucket_policy.test_mail_bucket]
}

resource "aws_ses_receipt_rule" "test_copy_of_answers_emails_to_s3" {
  name          = "test-copy-of-answers-emails-to-s3"
  rule_set_name = aws_ses_receipt_rule_set.test_mail.rule_set_name
  enabled       = true
  scan_enabled  = true
  recipients    = ["copy-of-answers-emails-tests@${var.email_domain}"]
  tls_policy    = "Require"

  s3_action {
    bucket_name       = aws_s3_bucket.test_mail_bucket.id
    object_key_prefix = "copy-of-answers-emails/"
    position          = 1
  }

  depends_on = [aws_s3_bucket_policy.test_mail_bucket]
}

resource "aws_ses_receipt_rule" "test_submission_emails_to_s3" {
  name          = "test-submission-emails-to-s3"
  rule_set_name = aws_ses_receipt_rule_set.test_mail.rule_set_name
  enabled       = true
  scan_enabled  = true
  recipients    = ["submissions-tests@${var.email_domain}"]
  tls_policy    = "Require"

  s3_action {
    bucket_name       = aws_s3_bucket.test_mail_bucket.id
    object_key_prefix = "submissions/"
    position          = 1
  }

  depends_on = [aws_s3_bucket_policy.test_mail_bucket]
}
