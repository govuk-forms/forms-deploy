resource "aws_cloudwatch_metric_alarm" "failed_bounce_notifications_job_executions" {
  alarm_name          = "${var.environment}-failed-bounce-notifications-job-executions"
  alarm_description   = <<EOF
There are one or more failed job executions for the bounce_notifications queue in forms-runner in the ${var.environment}
environment that will not automatically be retried.

Follow the runbook to respond to this: https://github.com/govuk-forms/forms-team/wiki/Runbooks#handle-failed-solid-queue-jobs

Only close this Zendesk ticket when we get another Zendesk ticket to tell us that the alarm is in the OK state.
EOF
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  namespace           = "Forms/Jobs"
  metric_name         = "FailedJobExecutions"
  statistic           = "Minimum"
  period              = 10 * 60 # 10 minutes
  threshold           = 1

  dimensions = {
    Environment = "${var.environment}"
    ServiceName = "forms-runner"
    QueueName   = "bounce_notifications"
  }

  treat_missing_data = "breaching"

  alarm_actions = [local.alert_severity.eu_west_2.info]
  ok_actions    = [local.alert_severity.eu_west_2.info]
}
