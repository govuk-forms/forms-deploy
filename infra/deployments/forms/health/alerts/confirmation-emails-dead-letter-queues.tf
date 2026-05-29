resource "aws_cloudwatch_metric_alarm" "confirmation_email_ses_bounces_and_complaints_dead_letter_queue_contains_message" {
  alarm_name          = "${var.environment}-confirmation-email-ses-bounces-and-complaints-dead-letter-queue-contains-message"
  alarm_description   = <<EOF
    There is a message in ${var.confirmation_email_bounces_and_complaints_dlq_name} in the ${var.environment} account.

    When SQS receives messages that are not processed successfully, it will add them to that queue's dead letter queue.

    NEXT STEPS:
    1. Look at the message in SQS console by visiting the URL below and clicking "Poll for messages"

    https://eu-west-2.console.aws.amazon.com/sqs/v3/home?region=eu-west-2#/queues/${urlencode("https://sqs.eu-west-2.amazonaws.com/${local.account_id}/${var.confirmation_email_bounces_and_complaints_dlq_name}")}/send-receive

    2. Look in Sentry and search Splunk for the SQS message ID to see if there are any relevant errors/logs.

    3. Once the issue is identified and fixed, resend the message to the SQS queue. Copy the contents of the message and
    go to the main SQS queue in the AWS console and send a new message, pasting in the message contents.

    4. Delete the message from the dead letter queue.
EOF
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Minimum"
  period              = 600
  threshold           = 1

  dimensions = {
    QueueName = var.confirmation_email_bounces_and_complaints_dlq_name
  }
  treat_missing_data = "notBreaching"

  alarm_actions = [local.alert_severity.eu_west_2.info]
  ok_actions    = [local.alert_severity.eu_west_2.info]
}
