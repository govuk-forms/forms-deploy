resource "aws_cloudwatch_event_rule" "renovate_schedule" {
  name                = "renovate"
  description         = "Starts the Renovate run"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "start_renovate" {
  #checkov:skip=CKV2_FORMS_AWS_6:Dead Letter Queue will be added when needed
  rule      = aws_cloudwatch_event_rule.renovate_schedule.name
  target_id = "StartRenovate"
  arn       = aws_codebuild_project.renovate.arn
  role_arn  = aws_iam_role.eventbridge.arn
}

resource "aws_cloudwatch_event_rule" "renovate_failure" {
  count       = var.failure_topic_arn != null ? 1 : 0
  name        = "renovate-failure"
  description = "Notifies when a Renovate run fails"

  event_pattern = jsonencode({
    source      = ["aws.codebuild"]
    detail-type = ["CodeBuild Build State Change"]
    detail = {
      project-name = [aws_codebuild_project.renovate.name]
      build-status = ["FAILED", "FAULT", "TIMED_OUT"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_renovate_failure_to_sns" {
  #checkov:skip=CKV2_FORMS_AWS_6:Dead Letter Queue not needed for failure notifications
  count     = var.failure_topic_arn != null ? 1 : 0
  target_id = "send-to-sns"
  rule      = aws_cloudwatch_event_rule.renovate_failure[0].name
  arn       = var.failure_topic_arn
  role_arn  = aws_iam_role.eventbridge.arn

  input_transformer {
    input_paths = {
      build_id = "$.detail.build-id"
      status   = "$.detail.build-status"
      region   = "$.region"
    }
    input_template = <<EOF
{
  "version": "1.0",
  "source": "custom",
  "content": {
    "textType": "client-markdown",
    "title": ":warning: Renovate run failed",
    "description": "The Renovate build ended with status <status>.",
    "keywords": [
      "renovate"
    ],
    "nextSteps": [
      "Visit https://<region>.console.aws.amazon.com/codesuite/codebuild/projects/renovate/history?region=<region> to review the build logs."
    ]
  }
}
EOF
  }
}
