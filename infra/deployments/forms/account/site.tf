terraform {
  backend "s3" {
    # bucket set in backend config file
    key    = "account.tfstate"
    region = "eu-west-2"

    use_lockfile = true
  }
}

provider "aws" {
  #checkov:skip=CKV2_FORMS_AWS_11:This root has never set default_tags. We should consider adding them, which tags every account-level resource and needs a reviewed plan in each environment.
  allowed_account_ids = [var.aws_account_id]
}
