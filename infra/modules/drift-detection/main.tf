data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.region
}

resource "aws_cloudwatch_log_group" "drift_check" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  name              = "/aws/codebuild/drift-check-${var.deployment_name}"
  retention_in_days = 30
}

locals {
  buildspec = {
    version = "0.2"
    env = {
      shell = "bash"
    }

    phases = {
      install = {
        commands = [
          "HCL2JSON_VERSION=\"v0.6.9\"",
          "HCL2JSON_SHA256=\"cb2ccf59a830829fe122e8dfb85d6ef2500aceda5af45a7c1052a4d2c46541f9\"",
          "curl https://github.com/tmccombs/hcl2json/releases/download/$${HCL2JSON_VERSION}/hcl2json_linux_arm64 -L -o hcl2json",
          "echo \"$${HCL2JSON_SHA256}  hcl2json\" | sha256sum -c -",
          "mv hcl2json /usr/local/bin/hcl2json",
          "chmod +x /usr/local/bin/hcl2json",
          "hcl2json --version"
        ]
      }
      build = {
        commands = [
          file("${path.module}/drift-detection.sh")
        ]
      }
    }
  }
}

resource "aws_codebuild_project" "drift_check" {
  #checkov:skip=CKV_AWS_147:Amazon Managed SSE is sufficient
  name          = "drift-check-${var.deployment_name}"
  description   = "Detects drift in Terraform roots for ${var.deployment_name} deployment"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  source {
    type      = "NO_SOURCE"
    buildspec = jsonencode(local.buildspec)
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.drift_check.name
      stream_name = "drift-detection"
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-aarch64-standard:4.0"
    type         = "ARM_CONTAINER"

    environment_variable {
      name  = "DEPLOYMENT_NAME"
      value = var.deployment_name
    }

    environment_variable {
      name  = "GIT_REPOSITORY_URL"
      value = var.git_repository_url
    }

    environment_variable {
      name  = "GIT_BRANCH"
      value = var.git_branch
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = local.aws_region
    }
  }
}
