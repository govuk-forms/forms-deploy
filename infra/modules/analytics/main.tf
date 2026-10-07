locals {
  table_bucket_name = "govuk-forms-${var.env_name}-analytics"
  namespace_name    = "forms"
  table_name        = "submission_events"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
