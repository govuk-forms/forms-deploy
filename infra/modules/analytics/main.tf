locals {
  table_bucket_name = "govuk-forms-${var.env_name}-analytics"
  namespace_name    = "forms"
  table_name        = "submission_events"
}
