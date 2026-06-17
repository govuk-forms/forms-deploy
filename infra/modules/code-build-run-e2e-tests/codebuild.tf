data "aws_caller_identity" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  project_name   = "${var.app_name}-e2e-tests-${var.environment_name}"
}

resource "aws_codebuild_project" "e2e" {
  #checkov:skip=CKV_AWS_147:Amazon Managed SSE is sufficient.
  name         = local.project_name
  description  = "Run end to end tests for ${var.app_name} in ${var.environment_name}"
  service_role = var.service_role_arn

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.log_group.name
      stream_name = "e2e"
    }
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "${var.container_registry}/end-to-end-tests:latest"
    type         = "LINUX_CONTAINER"

    image_pull_credentials_type = "SERVICE_ROLE"

    environment_variable {
      name  = "SETTINGS__FORMS_ENV"
      value = var.environment_name
    }

    environment_variable {
      name  = "SETTINGS__FORM_IDS__S3"
      value = var.s3_form_id
    }

    environment_variable {
      name  = "SETTINGS__FORMS_ADMIN__URL"
      value = var.forms_admin_url
    }

    environment_variable {
      name  = "SETTINGS__FORMS_ADMIN__AUTH__USERNAME"
      value = var.auth0_user_name_parameter_name
      type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "SETTINGS__FORMS_ADMIN__AUTH__PASSWORD"
      value = var.auth0_user_password_parameter_name
      type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "SETTINGS__FORMS_PRODUCT_PAGE__URL"
      value = var.product_pages_url
    }

    environment_variable {
      name  = "SETTINGS__FORMS_RUNNER__URL"
      value = var.forms_runner_url
    }

    environment_variable {
      name  = "SETTINGS__AWS__S3_SUBMISSION_BUCKET_NAME"
      value = var.aws_s3_bucket
    }

    environment_variable {
      name  = "SETTINGS__AWS__S3_SUBMISSION_IAM_ROLE_ARN"
      value = var.aws_s3_role_arn
    }

    environment_variable {
      name  = "SETTINGS__GOVUK_NOTIFY__API_KEY"
      value = var.notify_api_key_parameter_name
      type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "LOG_LEVEL"
      value = "debug"
    }

    environment_variable {
      name  = "TRACE"
      value = "1"
    }

    environment_variable {
      name  = "SETTINGS__SUBMISSION_STATUS_API__SECRET"
      type  = "PARAMETER_STORE"
      value = "/forms-runner-${var.environment_name}/submission_status_api_shared_secret"
    }

    environment_variable {
      name  = "SETTINGS__GOVUK_ONE_LOGIN__USER_EMAIL"
      value = var.one_login_user_email_parameter_name
      type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "SETTINGS__GOVUK_ONE_LOGIN__USER_PASSWORD"
      value = var.one_login_user_password_parameter_name
      type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "SETTINGS__GOVUK_ONE_LOGIN__USER_OTP_SECRET_KEY"
      value = var.one_login_user_otp_secret_key_parameter_name
      type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "SETTINGS__AWS__EMAIL_RECEIVER_S3_BUCKET_NAME"
      value = var.email_receiver_s3_bucket_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec/buildspec.yml")
  }
}
