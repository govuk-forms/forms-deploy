locals {
  submissions_without_immediate_delivery_selector = "{\"form.submission.without_immediate_delivery.count\", \"form.submission.mode\"=\"form\", \"@resource.deployment.environment.name\"=\"${var.environment}\"}"
}

resource "aws_cloudwatch_metric_alarm" "submissions_without_immediate_delivery" {
  alarm_name        = "${var.environment}-submissions-without-immediate-delivery"
  alarm_description = <<EOF
There are one or more live submissions with no immediate delivery in the ${var.environment} environment, or the metric
that counts them has not been reported for 30 minutes.

Every live submission must have at least one immediate delivery, otherwise it will never be delivered and will be
deleted after 30 days. forms-runner should refuse to save a live submission when the form has no immediate delivery
configured, so this suggests a bug or a problem with a form's delivery configuration.

The metric is recorded every 5 minutes by DeliveryMetricsJob, which is run by Solid Queue in the
forms-runner-queue-worker ECS task.

NEXT STEPS:
1. If the metric is missing, check that DeliveryMetricsJob is running. Look for errors in Sentry and in the
forms-runner-queue-worker logs, and check that the ADOT collector sidecar is healthy.
2. Otherwise, find the affected submissions in a Rails console in the forms-runner-queue-worker task:
   Submission.without_immediate_delivery.where(mode: "form")
3. Work out why they have no immediate delivery, fix the cause, and create and send an immediate delivery for each
one before it is deleted 30 days after it was submitted.

Only close this Zendesk ticket when we get another Zendesk ticket to tell us that the alarm is in the OK state.
EOF

  evaluation_criteria {
    promql_criteria {
      query           = <<EOF
max(max_over_time(${local.submissions_without_immediate_delivery_selector}[10m])) > 0
or
absent_over_time(${local.submissions_without_immediate_delivery_selector}[30m])
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
