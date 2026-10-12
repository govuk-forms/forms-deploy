# Firehose requires an S3 bucket for records it fails to deliver to the table.
module "error_bucket" {
  source = "../secure-bucket"
  name   = "govuk-forms-${var.env_name}-analytics-errors"
}
