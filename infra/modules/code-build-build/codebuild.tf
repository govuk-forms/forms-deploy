data "local_file" "terraform_version" {
  filename = "${path.module}/../../../.terraform-version"
}
locals {
  environment_variables = {
    "ENVIRONMENT"       = var.environment
    "TERRAFORM_VERSION" = trimspace(data.local_file.terraform_version.content)
  }

  deploy_directory = {
    "dev" = "development"
  }
}

resource "aws_codebuild_project" "this" {
  #checkov:skip=CKV_AWS_147:Amazon Managed SSE is sufficient.
  name         = var.project_name
  description  = var.project_description
  service_role = var.codebuild_service_role_arn

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.log_group.name
      stream_name = "terraform"
    }
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  dynamic "cache" {
    for_each = var.cache_bucket != null ? [1] : []

    content {
      type            = "S3"
      location        = var.cache_bucket
      cache_namespace = var.cache_namespace
    }
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-aarch64-standard:4.0"
    type         = "ARM_CONTAINER"

    # Create environment variables dynamically.
    # We use local variables by default but they can be overridden by var.environment_variables
    dynamic "environment_variable" {
      for_each = merge(local.environment_variables, var.environment_variables)

      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec
  }
}
