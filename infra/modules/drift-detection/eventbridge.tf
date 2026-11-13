resource "aws_cloudwatch_event_rule" "drift_check_schedule" {
  name                = "drift-check-${var.deployment_name}"
  description         = "Triggers drift detection for ${var.deployment_name} deployment"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "start_drift_check" {
  #checkov:skip=CKV2_FORMS_AWS_6:Dead Letter Queue will be added when needed
  rule      = aws_cloudwatch_event_rule.drift_check_schedule.name
  target_id = "StartDriftCheck"
  arn       = aws_codebuild_project.drift_check.arn
  role_arn  = aws_iam_role.eventbridge.arn
}

resource "aws_cloudwatch_event_rule" "drift_check_failure" {
  count       = var.drift_detected_topic_arn != null ? 1 : 0
  name        = "drift-check-${var.deployment_name}-failure"
  description = "Notifies when drift is detected in ${var.deployment_name} deployment"

  event_pattern = jsonencode({
    source      = ["custom"]
    detail-type = ["Terraform Drift Detection Result"]
    detail = {
      deployment-name = [var.deployment_name]
      drift-status    = ["FAILED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "send_drift_failure_to_sns" {
  #checkov:skip=CKV2_FORMS_AWS_6:Dead Letter Queue not needed for drift detection notifications
  count     = var.drift_detected_topic_arn != null ? 1 : 0
  target_id = "send-to-sns"
  rule      = aws_cloudwatch_event_rule.drift_check_failure[0].name
  arn       = var.drift_detected_topic_arn
  role_arn  = aws_iam_role.eventbridge.arn

  input_transformer {
    input_paths = {
      deployment_name = "$.detail.deployment-name"
      build_arn       = "$.detail.build-arn"
      drifted_roots   = "$.detail.drifted-roots"
      drift_count     = "$.detail.drift-count"
      total_count     = "$.detail.total-roots"
      region          = "$.region"
    }
    input_template = <<EOF
{
  "version": "1.0",
  "source": "custom",
  "content": {
    "textType": "client-markdown",
    "title": ":warning: Terraform Drift Detected: <deployment_name>",
    "description": "Drift has been detected in the <deployment_name> deployment.\n\n<drift_count> out of <total_count> Terraform roots have changes that need to be applied:\n\n<drifted_roots>\n\nPlease review the drift detection logs and reapply the affected roots.",
    "keywords": [
      "drift-detection",
      "<deployment_name>",
      "terraform"
    ],
    "nextSteps": [
      "Reapply the affected Terraform roots to bring infrastructure back in line with the IaC definitions: `make <deployment_name>_apply_all`",
      "Visit https://<region>.console.aws.amazon.com/codesuite/codebuild/projects/drift-check-<deployment_name>/history?region=<region> to review the drift detection build logs."
    ]
  }
}
EOF
  }
}
