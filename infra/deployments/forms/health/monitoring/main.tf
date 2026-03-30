resource "aws_cloudwatch_dashboard" "overview" {
  dashboard_name = "Overview"
  dashboard_body = templatefile("${path.module}/overview_dashboard_body.json.tpl", {
    environment_name = var.environment_name,
    # We use the metric math function ${LAST} in CloudWatch but Terraform interprets it as a variable substitution. To get around that we're providing the string ${LAST} to substitute into the template file. We also need to escape the "$" character by adding another "$" in front.
    LAST = "$${LAST}"
  })
}

resource "aws_cloudwatch_dashboard" "form_submissions" {
  dashboard_name = "FormSubmissions"
  dashboard_body = templatefile("${path.module}/form_submissions_dashboard_body.json.tpl", {
    environment_name = var.environment_name,
  })
}

module "runner_scheduled_smoke_tests" {
  count = var.scheduled_smoke_tests_settings.enable_scheduled_smoke_tests ? 1 : 0

  source = "./smoke-test"

  environment         = var.environment_name
  container_registry  = var.container_registry
  deploy_account_id   = var.deploy_account_id
  frequency_minutes   = var.scheduled_smoke_tests_settings.frequency_minutes
  enable_alerting     = var.scheduled_smoke_tests_settings.enable_alerting
  test_name           = "runner-smoke-test"
  rspec_path          = "spec/smoke_tests/smoke_test_runner_spec.rb"
  alarm_sns_topic_arn = var.smoke_test_alarm_sns_topic_arn
  alarm_description   = <<EOF
    The runner smoke tests are failing. Users might not be able to complete and
    submit forms.

    To investigate:
    - Check the runner-smoke-test CodeBuild project logs for information
    where the tests failed.
    - Attempt to fill in a form in the ${var.environment_name} environment to
    verify if there is an issue. The tests use the form
    ${var.scheduled_smoke_tests_settings.form_url}. There may be an
    intermittent issue so continue to next step regardless
    - Check the application logs for errors.
    - If this is not a false alarm, begin an incident and follow the incident response at
    https://github.com/govuk-forms/forms-team/wiki/Incident-Response.
    EOF
  codebuild_environment_variables = {
    SMOKE_TEST_FORM_URL = var.scheduled_smoke_tests_settings.form_url
  }
}
