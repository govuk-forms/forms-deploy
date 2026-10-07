locals {
  # Created by the ecs-service module, see infra/modules/ecs-service/ecs.tf
  log_group_name = "/aws/ecs/forms-runner-${var.env_name}"

  table_bucket_name = "govuk-forms-${var.env_name}-analytics"
  namespace_name    = "forms"
  table_name        = "submission_events"
  stream_name       = "submission-events-${var.env_name}"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_cloudwatch_log_group" "forms_runner" {
  name = local.log_group_name
}
