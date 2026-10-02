data "terraform_remote_state" "forms_health" {
  backend = "s3"

  config = {
    key    = "health.tfstate"
    bucket = var.bucket
    region = "eu-west-2"

    use_lockfile = true
  }
}

data "terraform_remote_state" "account" {
  backend = "s3"

  config = {
    key    = "account.tfstate"
    bucket = var.bucket
    region = "eu-west-2"

    use_lockfile = true
  }
}

data "terraform_remote_state" "forms_environment" {
  backend = "s3"

  config = {
    key    = "network.tfstate"
    bucket = var.bucket
    region = "eu-west-2"

    use_lockfile = true
  }
}
