terraform {
  required_version = "1.14.0"
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "2.8.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.54.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.92.0"
    }
    auth0 = {
      source  = "auth0/auth0"
      version = "1.51.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }
}
