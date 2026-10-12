# Firehose requires an S3 bucket for records it fails to deliver to the table.
# Events the transform Lambda fails to put to the stream are written here too.
module "error_bucket" {
  source = "../secure-bucket"
  name   = "govuk-forms-${var.env_name}-analytics-errors"
}
