data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.region
}

resource "aws_cloudwatch_log_group" "renovate" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  name              = "/aws/codebuild/renovate"
  retention_in_days = 30
}

# The values are set by hand once the GitHub App exists. See infra/README.md.
resource "aws_ssm_parameter" "github_app_id" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  name  = "/renovate/github-app-id"
  type  = "SecureString"
  value = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "github_app_private_key" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  name  = "/renovate/github-app-private-key"
  type  = "SecureString"
  value = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}

locals {
  buildspec = {
    version = "0.2"
    env = {
      shell = "bash"
    }

    phases = {
      build = {
        commands = [
          "echo '${base64encode(file("${path.module}/mint-token.js"))}' | base64 -d > /tmp/mint-token.js",
          file("${path.module}/run-renovate.sh"),
        ]
      }
    }
  }
}

resource "aws_codebuild_project" "renovate" {
  #checkov:skip=CKV_AWS_147:Amazon Managed SSE is sufficient
  name          = "renovate"
  description   = "Runs Renovate against ${join(", ", var.repositories)}"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  source {
    type      = "NO_SOURCE"
    buildspec = jsonencode(local.buildspec)
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.renovate.name
      stream_name = "renovate"
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = var.renovate_image
    image_pull_credentials_type = "CODEBUILD"
    type                        = "LINUX_CONTAINER"

    environment_variable {
      name  = "GITHUB_APP_ID"
      type  = "PARAMETER_STORE"
      value = aws_ssm_parameter.github_app_id.name
    }

    environment_variable {
      name  = "GITHUB_APP_PRIVATE_KEY"
      type  = "PARAMETER_STORE"
      value = aws_ssm_parameter.github_app_private_key.name
    }

    environment_variable {
      name  = "GITHUB_ORG"
      value = var.github_organisation
    }

    environment_variable {
      name  = "GITHUB_REPOSITORIES"
      value = join(",", var.repositories)
    }

    environment_variable {
      name  = "RENOVATE_PLATFORM"
      value = "github"
    }

    environment_variable {
      name  = "RENOVATE_REPOSITORIES"
      value = join(",", var.repositories)
    }

    environment_variable {
      name  = "RENOVATE_AUTODISCOVER"
      value = "false"
    }

    # The repositories configure themselves, so skip the onboarding pull requests.
    environment_variable {
      name  = "RENOVATE_ONBOARDING"
      value = "false"
    }

    environment_variable {
      name  = "RENOVATE_REQUIRE_CONFIG"
      value = "optional"
    }

    # GitHub signs commits made through its API for an App.
    environment_variable {
      name  = "RENOVATE_PLATFORM_COMMIT"
      value = "enabled"
    }

    environment_variable {
      name  = "RENOVATE_BASE_DIR"
      value = "/tmp/renovate"
    }

    environment_variable {
      name  = "LOG_LEVEL"
      value = "debug"
    }

    dynamic "environment_variable" {
      for_each = var.dry_run != null ? [var.dry_run] : []
      content {
        name  = "RENOVATE_DRY_RUN"
        value = environment_variable.value
      }
    }
  }
}
