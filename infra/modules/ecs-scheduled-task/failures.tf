resource "aws_cloudwatch_event_rule" "failed" {
  count = var.failure_alert != null ? 1 : 0

  name        = var.failure_alert.rule_name
  description = var.failure_alert.description

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    resources = [
      {
        wildcard = "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task/*"
      }
    ]

    detail = {
      lastStatus = ["STOPPED"]
      containers = {
        name     = [var.container_name]
        exitCode = [{ "anything-but" : [0] }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "failed_alert" {
  count = var.failure_alert != null ? 1 : 0

  rule = aws_cloudwatch_event_rule.failed[0].name
  arn  = var.zendesk_sns_topic_arn

  input_transformer {
    input_template = var.failure_alert.input_template
  }

  dead_letter_config {
    arn = var.eventbridge_dead_letter_queue_arn
  }
}
