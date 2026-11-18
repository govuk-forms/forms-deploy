locals {
  oldest_undelivered_delivery_age_selector = "{\"form.submission.delivery.oldest_undelivered.age\", \"form.submission.mode\"=\"form\", \"@resource.deployment.environment.name\"=\"${var.environment}\"}"
}

resource "aws_cloudwatch_metric_alarm" "submission_delivery_not_made_within_24_hours" {
  alarm_name        = "${var.environment}-submission-delivery-not-made-within-24-hours"
  alarm_description = <<EOF
A live submission in the ${var.environment} environment has an immediate delivery that has not been delivered more
than 24 hours after the submission was made, or the metric that measures this has not been reported for 30 minutes.

Automatic retries will have finished well before 24 hours, so the delivery needs to be recovered manually. The
submission will be deleted 30 days after it was made, whether or not it has been delivered.

The metric is recorded every 5 minutes by DeliveryMetricsJob, which is run by Solid Queue in the
forms-runner-queue-worker ECS task. The form.submission.delivery.method attribute shows which delivery method is
affected.

NEXT STEPS:
1. If the metric is missing, check that DeliveryMetricsJob is running. Look for errors in Sentry and in the
forms-runner-queue-worker logs, and check that the ADOT collector sidecar is healthy.
2. Otherwise, find the undelivered deliveries in a Rails console in the forms-runner-queue-worker task:
   Delivery.immediate.undelivered.joins(:submissions).where(submissions: { mode: "form" }).where(submissions: { created_at: ..24.hours.ago })
3. For each one, find out why it failed using the submissions:inspect_submission_deliveries rake task, Sentry, and any
failed Solid Queue jobs. If the cause is outside our control, such as a bounced email address or a misconfigured S3
bucket, contact the form owner.
4. Once the cause is fixed, retry the delivery, either by retrying the failed Solid Queue job or with the
submissions:retry_failed_deliveries rake task.

Only close this Zendesk ticket when we get another Zendesk ticket to tell us that the alarm is in the OK state.
EOF

  evaluation_criteria {
    promql_criteria {
      query           = <<EOF
max(max_over_time(${local.oldest_undelivered_delivery_age_selector}[10m])) > 86400
or
absent_over_time(${local.oldest_undelivered_delivery_age_selector}[30m])
EOF
      pending_period  = 300
      recovery_period = 300
    }
  }

  evaluation_interval = 60

  alarm_actions   = [local.alert_severity.eu_west_2.info]
  ok_actions      = [local.alert_severity.eu_west_2.info]
  actions_enabled = var.enable_alert_actions
}
