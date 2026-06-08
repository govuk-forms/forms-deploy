resource "aws_cloudwatch_metric_alarm" "confirmation_email_complaints" {
  alarm_name          = "${var.environment}-confirmation-email-complaints"
  alarm_description   = <<EOF
The complaint rate for confirmation emails sent using SES is greater than 0.1% in the ${var.environment} environment.

If the rate goes above 0.5%, AWS might pause our ability to send emails, so this needs to be investigated and resolved
as soon as possible.

Only close this Zendesk ticket when we get another Zendesk ticket to tell us that the alarm is in the OK state.
EOF
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  namespace           = "AWS/SES"
  metric_name         = "Reputation.ComplaintRate"
  statistic           = "Average"
  period              = 5 * 60 # 5 minutes
  threshold           = 0.001  # 0.1%

  dimensions = {
    "ses:configuration-set" = var.form_confirmations_configuration_set_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [local.alert_severity.eu_west_2.info]
  ok_actions    = [local.alert_severity.eu_west_2.info]
}
