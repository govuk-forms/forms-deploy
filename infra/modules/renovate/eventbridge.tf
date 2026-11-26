resource "aws_cloudwatch_event_rule" "renovate_schedule" {
  name                = "renovate"
  description         = "Starts the Renovate run"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "start_renovate" {
  #checkov:skip=CKV2_FORMS_AWS_6:The request is only a row in the runs table, and the schedule runs again tomorrow
  rule      = aws_cloudwatch_event_rule.renovate_schedule.name
  target_id = "StartRenovate"
  arn       = aws_lambda_function.orchestrator.arn
  input     = jsonencode({ action = "request", repos = "all", mode = "full" })
}

resource "aws_lambda_permission" "schedule" {
  statement_id  = "AllowSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.renovate_schedule.arn
}

# A build that ends frees its repo, which may have a request waiting.
resource "aws_cloudwatch_event_rule" "renovate_build_ended" {
  name        = "renovate-build-ended"
  description = "Tells the orchestrator that a Renovate build has ended"

  event_pattern = jsonencode({
    source      = ["aws.codebuild"]
    detail-type = ["CodeBuild Build State Change"]
    detail = {
      project-name = [aws_codebuild_project.renovate.name]
      build-status = ["SUCCEEDED", "FAILED", "FAULT", "TIMED_OUT", "STOPPED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "build_ended" {
  #checkov:skip=CKV2_FORMS_AWS_6:The sweep starts anything a missed event leaves waiting
  rule      = aws_cloudwatch_event_rule.renovate_build_ended.name
  target_id = "Orchestrator"
  arn       = aws_lambda_function.orchestrator.arn
}

resource "aws_lambda_permission" "build_ended" {
  statement_id  = "AllowBuildEnded"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.renovate_build_ended.arn
}

# Starts anything left waiting if an event was missed or a lease ran out.
resource "aws_cloudwatch_event_rule" "renovate_sweep" {
  name                = "renovate-sweep"
  description         = "Has the orchestrator start any repo that is waiting"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "sweep" {
  #checkov:skip=CKV2_FORMS_AWS_6:The sweep runs again in five minutes
  rule      = aws_cloudwatch_event_rule.renovate_sweep.name
  target_id = "Orchestrator"
  arn       = aws_lambda_function.orchestrator.arn
  input     = jsonencode({ action = "reconcile" })
}

resource "aws_lambda_permission" "sweep" {
  statement_id  = "AllowSweep"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.renovate_sweep.arn
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
  role_arn  = aws_iam_role.eventbridge[0].arn

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
