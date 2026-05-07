resource "aws_cloudwatch_event_rule" "terraform_applied" {
  for_each = module.other_accounts.environment_accounts_id

  name        = "terraform-applied-from-${each.key}"
  description = "Match Terraform application success events from the ${each.key} account"
  role_arn    = aws_iam_role.eventbridge_actor.arn

  event_pattern = jsonencode({
    source      = ["uk.gov.service.forms"],
    account     = [each.value]
    detail-type = ["Terraform application succesful"]
  })
}

resource "aws_cloudwatch_event_target" "terraform_applied_development_to_staging" {
  target_id = "from-development-to-staging"
  rule      = aws_cloudwatch_event_rule.terraform_applied["development"].name
  role_arn  = aws_iam_role.eventbridge_actor.arn
  arn       = "arn:aws:events:eu-west-2:${module.other_accounts.environment_accounts_id["staging"]}:event-bus/default"

  dead_letter_config {
    arn = aws_sqs_queue.event_bridge_dlq.arn
  }
}

resource "aws_cloudwatch_event_target" "terraform_applied_development_to_production" {
  target_id = "from-development-to-production"
  rule      = aws_cloudwatch_event_rule.terraform_applied["development"].name
  role_arn  = aws_iam_role.eventbridge_actor.arn
  arn       = "arn:aws:events:eu-west-2:${module.other_accounts.environment_accounts_id["production"]}:event-bus/default"

  dead_letter_config {
    arn = aws_sqs_queue.event_bridge_dlq.arn
  }
}

resource "aws_cloudwatch_event_target" "terraform_applied_staging_to_development" {
  target_id = "from-staging-to-development"
  rule      = aws_cloudwatch_event_rule.terraform_applied["staging"].name
  role_arn  = aws_iam_role.eventbridge_actor.arn
  arn       = "arn:aws:events:eu-west-2:${module.other_accounts.environment_accounts_id["development"]}:event-bus/default"

  dead_letter_config {
    arn = aws_sqs_queue.event_bridge_dlq.arn
  }
}

resource "aws_cloudwatch_event_target" "terraform_applied_staging_to_production" {
  target_id = "from-staging-to-production"
  rule      = aws_cloudwatch_event_rule.terraform_applied["staging"].name
  role_arn  = aws_iam_role.eventbridge_actor.arn
  arn       = "arn:aws:events:eu-west-2:${module.other_accounts.environment_accounts_id["production"]}:event-bus/default"

  dead_letter_config {
    arn = aws_sqs_queue.event_bridge_dlq.arn
  }
}

resource "aws_cloudwatch_event_target" "terraform_applied_production_to_development" {
  target_id = "from-production-to-development"
  rule      = aws_cloudwatch_event_rule.terraform_applied["production"].name
  role_arn  = aws_iam_role.eventbridge_actor.arn
  arn       = "arn:aws:events:eu-west-2:${module.other_accounts.environment_accounts_id["development"]}:event-bus/default"

  dead_letter_config {
    arn = aws_sqs_queue.event_bridge_dlq.arn
  }
}

resource "aws_cloudwatch_event_target" "terraform_applied_production_to_staging" {
  target_id = "from-production-to-staging"
  rule      = aws_cloudwatch_event_rule.terraform_applied["production"].name
  role_arn  = aws_iam_role.eventbridge_actor.arn
  arn       = "arn:aws:events:eu-west-2:${module.other_accounts.environment_accounts_id["staging"]}:event-bus/default"

  dead_letter_config {
    arn = aws_sqs_queue.event_bridge_dlq.arn
  }
}

resource "aws_cloudwatch_event_rule" "log_terraform_applied_events" {
  name        = "log-terraform-applied-events-in-cloudwatch"
  description = "Send events to CloudWatch"
  event_pattern = jsonencode({
    source      = ["uk.gov.service.forms"],
    detail-type = ["Terraform application succesful"]
  })
}

resource "aws_cloudwatch_log_group" "terraform_applied_events" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  name              = "/aws/events/terraform-applied-events"
  retention_in_days = 30
}

resource "aws_cloudwatch_event_target" "log_terraform_applied_events_to_cloudwatch" {
  target_id = "log-to-cloudwatch"
  rule      = aws_cloudwatch_event_rule.log_terraform_applied_events.name
  arn       = aws_cloudwatch_log_group.terraform_applied_events.arn

  dead_letter_config {
    arn = aws_sqs_queue.event_bridge_dlq.arn
  }
}

data "aws_iam_policy_document" "log_group_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.ecr_push_events.arn}:*"
    ]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }
  }
}
