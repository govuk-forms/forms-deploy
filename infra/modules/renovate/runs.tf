# One row per repo. It only holds what asking for a run again would rebuild.
resource "aws_dynamodb_table" "runs" {
  #checkov:skip=CKV_AWS_28:Rows only record a pending request and a running build. Asking for a run again rebuilds them.
  #checkov:skip=CKV_AWS_119:Encrypted with the AWS owned key, as nothing in the rows is sensitive
  name         = "renovate-runs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "repo"

  attribute {
    name = "repo"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}
