data "terraform_remote_state" "rds" {
  backend = "s3"

  config = {
    key    = "rds.tfstate"
    bucket = var.bucket
    region = "eu-west-2"

    use_lockfile = true
  }
}
