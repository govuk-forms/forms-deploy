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
  cache_dir = "/tmp/renovate/cache"

  buildspec = {
    version = "0.2"
    env = {
      shell = "bash"
    }

    cache = {
      paths = ["${local.cache_dir}/**/*"]
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

  # The cache below is one object, overwritten by each build, which is only safe
  # while builds run one at a time.
  concurrent_build_limit = 1

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

  cache {
    type     = "S3"
    location = "${module.cache_bucket.name}/renovate"
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

    # Docker Hub refuses anonymous requests for page 11 of a tag list, and
    # Renovate then drops the dates from pages 1 to 10, so the release age never
    # holds anything back. renovatebot/renovate#46925.
    environment_variable {
      name  = "RENOVATE_DOCKER_MAX_PAGES"
      value = "10"
    }

    # The only command a repository's config may ask Renovate to run. It refreshes
    # the hash that sits next to the hcl2json version.
    environment_variable {
      name  = "RENOVATE_ALLOWED_COMMANDS"
      value = jsonencode(["^\\./support/update-hcl2json-sha\\.sh v[0-9]+\\.[0-9]+\\.[0-9]+$"])
    }

    environment_variable {
      name  = "RENOVATE_CACHE_DIR"
      value = local.cache_dir
    }

    environment_variable {
      name  = "RENOVATE_REPOSITORY_CACHE"
      value = "enabled"
    }

    # One object per repo, so builds for different repos never write the same
    # file.
    environment_variable {
      name  = "RENOVATE_REPOSITORY_CACHE_TYPE"
      value = "s3://${module.cache_bucket.name}/repository-cache/"
    }

    # One JSON object per line, so the metric filters in monitoring.tf can read
    # the level and repository.
    environment_variable {
      name  = "RENOVATE_LOG_FORMAT"
      value = "json"
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
