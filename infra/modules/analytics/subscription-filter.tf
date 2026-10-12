# This uses the second and final subscription filter slot on the forms-runner
# log group (CloudWatch Logs allows two per log group; the first is
# via-cribl-to-splunk in infra/modules/ecs-service/logging.tf).
resource "aws_cloudwatch_log_subscription_filter" "submission_events" {
  name = "submission-events-to-lambda"

  log_group_name = data.aws_cloudwatch_log_group.forms_runner.name

  filter_pattern  = "{ $.event = \"form_submission\" || $.event = \"form_preview_submission\" }"
  destination_arn = aws_lambda_function.transform.arn

  # CloudWatch Logs checks it can invoke the function when the filter is created
  depends_on = [aws_lambda_permission.cloudwatch_logs]
}

resource "aws_lambda_permission" "cloudwatch_logs" {
  statement_id   = "AllowInvokeFromFormsRunnerLogGroup"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.transform.function_name
  principal      = "logs.amazonaws.com"
  source_arn     = "${data.aws_cloudwatch_log_group.forms_runner.arn}:*"
  source_account = data.aws_caller_identity.current.account_id
}
