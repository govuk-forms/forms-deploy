# IAM permissions for AWS Distro for OpenTelemetry sidecar
# These permissions allow the ADOT collector to send traces to X-Ray and metrics
# to CloudWatch via the OTLP endpoint.
# Note: Container logs are handled by the task execution role, not the task role

data "aws_iam_policy_document" "adot_permissions" {
  count = var.enable_opentelemetry ? 1 : 0

  # X-Ray permissions for trace collection
  statement {
    sid    = "XRayAccess"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = ["*"]
  }

  # CloudWatch OTLP metrics endpoint (SigV4 service name: monitoring)
  statement {
    sid    = "CloudWatchMetricsOTLP"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "adot_policy" {
  count  = var.enable_opentelemetry ? 1 : 0
  name   = "${var.env_name}-${var.application}-adot-collector"
  policy = data.aws_iam_policy_document.adot_permissions[0].json
}

resource "aws_iam_role_policy_attachment" "adot_policy_attachment" {
  count      = var.enable_opentelemetry ? 1 : 0
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.adot_policy[0].arn
}
