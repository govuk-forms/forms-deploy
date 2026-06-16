module "artifact_bucket" {
  source = "../secure-bucket"
  name   = "pipeline-e2e-image"

  access_logging_enabled = true
}

resource "aws_codepipeline" "main" {
  #checkov:skip=CKV_AWS_219:Amazon Managed SSE is sufficient.
  name           = "e2e-image"
  role_arn       = aws_iam_role.this.arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"

  artifact_store {
    type     = "S3"
    location = module.artifact_bucket.name
  }

  stage {
    name = "Source"
    action {
      name             = "get-forms-e2e-tests"
      namespace        = "get-forms-e2e-tests"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["forms_e2e_tests"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "govuk-forms/forms-e2e-tests"
        BranchName       = var.forms_e2e_tests_branch
        DetectChanges    = true
      }
    }
  }

  stage {
    name = "Build-test-and-push"

    action {
      name            = "Build"
      namespace       = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["forms_e2e_tests"]
      configuration = {
        ProjectName          = module.docker_build.name
        EnvironmentVariables = jsonencode([{ "name" : "GIT_SHA", "value" : "#{get-forms-e2e-tests.CommitId}", "type" : "PLAINTEXT" }])
      }
    }
  }
}

module "docker_build" {
  source                         = "../code-build-docker-build"
  project_name                   = "docker-build-e2e-tests"
  project_description            = "Build the image used to run the end to end tests"
  image_name                     = "end-to-end-tests"
  tag_latest                     = true
  docker_username_parameter_path = "/docker/username"
  docker_password_parameter_path = "/docker/password"
  artifact_store_arn             = module.artifact_bucket.arn
  build_directory                = "."
  codestar_connection_arn        = var.codestar_connection_arn
  ecr_repository_url             = var.ecr_repository_url

  # Selenium is not compatible with aarch64.
  code_build_project_compute_arch = "LINUX_CONTAINER"
  code_build_project_image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"

  extra_env_vars = [
    {
      name  = "SETTINGS__FORMS_ENV"
      value = "staging"
      type  = "PLAINTEXT"
    },
    {
      name  = "SETTINGS__FORM_IDS__SMOKE_TEST"
      value = "12148"
      type  = "PLAINTEXT"
    },
    {
      name  = "SETTINGS__FORM_IDS__S3"
      value = "13657"
      type  = "PLAINTEXT"
    },
    {
      name  = "SETTINGS__FORMS_ADMIN__URL"
      value = "https://admin.staging.forms.service.gov.uk"
      type  = "PLAINTEXT"
    },
    {
      name  = "SETTINGS__FORMS_ADMIN__AUTH__USERNAME"
      value = "/staging/automated-tests/e2e/auth0/email-username"
      type  = "PARAMETER_STORE"
    },
    {
      name  = "SETTINGS__FORMS_ADMIN__AUTH__PASSWORD"
      value = "/staging/automated-tests/e2e/auth0/auth0-user-password"
      type  = "PARAMETER_STORE"
    },
    {
      name  = "SETTINGS__FORMS_PRODUCT_PAGE__URL"
      value = "https://staging.forms.service.gov.uk"
      type  = "PLAINTEXT"
    },
    {
      name  = "SETTINGS__FORMS_RUNNER__URL"
      value = "https://submit.staging.forms.service.gov.uk"
      type  = "PLAINTEXT"
    },
    {
      name  = "SETTINGS__AWS__FILE_UPLOAD_S3_BUCKET_NAME"
      value = "govuk-forms-submissions-to-s3-test"
      type  = "PLAINTEXT"
    },
    {
      name  = "SETTINGS__AWS__S3_SUBMISSION_IAM_ROLE_ARN"
      value = "arn:aws:iam::972536609845:role/govuk-s3-end-to-end-test-staging"
      type  = "PLAINTEXT"
    },
    {
      name  = "SETTINGS__GOVUK_NOTIFY__API_KEY"
      value = "/staging/automated-tests/e2e/notify/api-key"
      type  = "PARAMETER_STORE"
    },
    {
      name  = "SETTINGS__SUBMISSION_STATUS_API__SECRET"
      value = "/staging/automated-tests/e2e/runner/submission_status_api_shared_secret"
      type  = "PARAMETER_STORE"
    },
    {
      name  = "SETTINGS__GOVUK_ONE_LOGIN__USER_EMAIL"
      value = "/staging/automated-tests/e2e/one-login/user-email"
      type  = "PARAMETER_STORE"
    },
    {
      name  = "SETTINGS__GOVUK_ONE_LOGIN__USER_PASSWORD"
      value = "/staging/automated-tests/e2e/one-login/user-password"
      type  = "PARAMETER_STORE"
    },
    {
      name  = "SETTINGS__GOVUK_ONE_LOGIN__USER_OTP_SECRET_KEY"
      value = "/staging/automated-tests/e2e/one-login/user-otp-secret-key"
      type  = "PARAMETER_STORE"
    }
  ]
}
