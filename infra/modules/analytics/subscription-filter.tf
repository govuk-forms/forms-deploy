# This uses the second and final subscription filter slot on the forms-runner
# log group (CloudWatch Logs allows two per log group; the first is
# via-cribl-to-splunk in infra/modules/ecs-service/logging.tf).
resource "aws_cloudwatch_log_subscription_filter" "submission_events" {
  name = "submission-events-to-firehose"

  log_group_name = data.aws_cloudwatch_log_group.forms_runner.name

  filter_pattern  = "{ $.event = \"form_submission\" }"
  destination_arn = aws_kinesis_firehose_delivery_stream.submission_events.arn
  role_arn        = aws_iam_role.log_subscription.arn
}
