# The value is set by hand once the GitHub App's webhook is configured.
resource "aws_ssm_parameter" "github_webhook_secret" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  count = var.webhook_enabled ? 1 : 0
  name  = "/renovate/github-webhook-secret"
  type  = "SecureString"
  value = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_cloudwatch_log_group" "webhook" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  count             = var.webhook_enabled ? 1 : 0
  name              = "/aws/lambda/renovate-webhook"
  retention_in_days = 30
}

data "aws_iam_policy_document" "webhook_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "webhook" {
  count              = var.webhook_enabled ? 1 : 0
  name               = "lambda-renovate-webhook"
  assume_role_policy = data.aws_iam_policy_document.webhook_assume_role.json
}

data "aws_iam_policy_document" "webhook" {
  count = var.webhook_enabled ? 1 : 0

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.webhook[0].arn}:*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.github_webhook_secret[0].arn]
    effect    = "Allow"
  }

  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.orchestrator.arn]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "webhook" {
  count  = var.webhook_enabled ? 1 : 0
  name   = "lambda-renovate-webhook"
  path   = "/"
  policy = data.aws_iam_policy_document.webhook[0].json
}

resource "aws_iam_role_policy_attachment" "webhook" {
  count      = var.webhook_enabled ? 1 : 0
  policy_arn = aws_iam_policy.webhook[0].arn
  role       = aws_iam_role.webhook[0].id
}

resource "aws_lambda_function" "webhook" {
  #checkov:skip=CKV_AWS_272:Code signing isn't used for our other Lambdas
  #checkov:skip=CKV_AWS_116:GitHub redelivers on demand, so a dead letter queue adds nothing
  #checkov:skip=CKV_AWS_117:The function only talks to AWS APIs and doesn't need the VPC
  #checkov:skip=CKV_AWS_50:X-Ray isn't needed for a function this small
  #checkov:skip=CKV_AWS_173:The environment variables hold names, not secrets. The webhook secret is read from SSM.
  count         = var.webhook_enabled ? 1 : 0
  function_name = "renovate-webhook"
  description   = "Asks for a Renovate run when the Dependency Dashboard or a Renovate pull request is edited"
  role          = aws_iam_role.webhook[0].arn

  runtime = "nodejs22.x"
  handler = "index.handler"
  # GitHub delivers a burst of edits at once and doesn't retry a throttled
  # delivery, so this has to be well above the number of PRs ticked together.
  reserved_concurrent_executions = 30
  timeout                        = 10

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      ORCHESTRATOR_FUNCTION    = aws_lambda_function.orchestrator.function_name
      BOT_LOGIN                = "${var.github_app_slug}[bot]"
      WEBHOOK_SECRET_PARAMETER = aws_ssm_parameter.github_webhook_secret[0].name
    }
  }

  depends_on = [aws_cloudwatch_log_group.webhook, aws_iam_role_policy_attachment.webhook]
}

resource "aws_lambda_function_url" "webhook" {
  #checkov:skip=CKV_AWS_258:GitHub can't sign requests for AWS. The function checks GitHub's HMAC signature instead.
  count              = var.webhook_enabled ? 1 : 0
  function_name      = aws_lambda_function.webhook[0].function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "webhook_url" {
  #checkov:skip=CKV_AWS_301:GitHub has to be able to call the function URL. The function checks the signature.
  #checkov:skip=CKV_AWS_364:GitHub has to be able to call the function URL. The function checks the signature.
  count                  = var.webhook_enabled ? 1 : 0
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.webhook[0].function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "webhook_invoke" {
  #checkov:skip=CKV_AWS_301:GitHub has to be able to call the function URL. The function checks the signature.
  #checkov:skip=CKV_AWS_364:GitHub has to be able to call the function URL. The function checks the signature.
  count                    = var.webhook_enabled ? 1 : 0
  statement_id             = "AllowInvokeViaFunctionUrl"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.webhook[0].function_name
  principal                = "*"
  invoked_via_function_url = true
}

# The handler logs one JSON object per delivery, with a timestamp and request ID
# in front, so the pattern matches the two messages that mean a delivery was
# refused: a signature that doesn't match, and a secret that was never set.
resource "aws_cloudwatch_log_metric_filter" "webhook_rejected" {
  count          = var.webhook_enabled ? 1 : 0
  name           = "renovate-webhook-rejected"
  log_group_name = aws_cloudwatch_log_group.webhook[0].name
  pattern        = "?\"invalid signature\" ?\"webhook secret is not set\""

  metric_transformation {
    name      = "WebhookRejected"
    namespace = "Renovate"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "webhook_rejected" {
  count               = var.webhook_enabled && var.failure_topic_arn != null ? 1 : 0
  alarm_name          = "renovate-webhook-rejected"
  alarm_description   = "The Renovate webhook has refused several deliveries: the secret may not match GitHub's, or someone is probing the URL"
  namespace           = "Renovate"
  metric_name         = "WebhookRejected"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.failure_topic_arn]

  depends_on = [aws_cloudwatch_log_metric_filter.webhook_rejected]
}
