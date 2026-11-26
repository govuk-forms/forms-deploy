data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_cloudwatch_log_group" "orchestrator" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  name              = "/aws/lambda/renovate-orchestrator"
  retention_in_days = 30
}

data "aws_iam_policy_document" "orchestrator_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "orchestrator" {
  name               = "lambda-renovate-orchestrator"
  assume_role_policy = data.aws_iam_policy_document.orchestrator_assume_role.json
}

data "aws_iam_policy_document" "orchestrator" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.orchestrator.arn}:*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["codebuild:StartBuild"]
    resources = [aws_codebuild_project.renovate.arn]
    effect    = "Allow"
  }

  statement {
    actions   = ["ssm:GetParameters"]
    resources = [aws_ssm_parameter.github_app_id.arn, aws_ssm_parameter.github_app_private_key.arn]
    effect    = "Allow"
  }

  statement {
    actions   = ["ssm:PutParameter"]
    resources = ["arn:aws:ssm:${local.aws_region}:${local.aws_account_id}:parameter${local.token_parameter_prefix}/*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["dynamodb:Scan", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.runs.arn]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "orchestrator" {
  name   = "lambda-renovate-orchestrator"
  path   = "/"
  policy = data.aws_iam_policy_document.orchestrator.json
}

resource "aws_iam_role_policy_attachment" "orchestrator" {
  policy_arn = aws_iam_policy.orchestrator.arn
  role       = aws_iam_role.orchestrator.id
}

resource "aws_lambda_function" "orchestrator" {
  #checkov:skip=CKV_AWS_272:Code signing isn't used for our other Lambdas
  #checkov:skip=CKV_AWS_116:EventBridge and the webhook retry a failed invocation, and the sweep starts anything missed
  #checkov:skip=CKV_AWS_117:The function only talks to AWS APIs and doesn't need the VPC
  #checkov:skip=CKV_AWS_50:X-Ray isn't needed for a function this small
  #checkov:skip=CKV_AWS_173:The environment variables hold names, not secrets
  function_name = "renovate-orchestrator"
  description   = "Starts a Renovate build for each repo with a pending request, within the build limit"
  role          = aws_iam_role.orchestrator.arn

  runtime = "nodejs22.x"
  handler = "orchestrator.handler"
  # Several invocations at once are safe, because starting a repo is a
  # conditional update.
  reserved_concurrent_executions = 5
  timeout                        = 30

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      TABLE_NAME        = aws_dynamodb_table.runs.name
      PROJECT_NAME      = aws_codebuild_project.renovate.name
      CACHE_LOCATION    = "${module.cache_bucket.name}/renovate"
      CONCURRENT_BUILDS = var.concurrent_builds
      GITHUB_ORG        = var.github_organisation
      APP_ID_PARAMETER  = aws_ssm_parameter.github_app_id.name
      APP_KEY_PARAMETER = aws_ssm_parameter.github_app_private_key.name
      # The tokens the builds read, one parameter per repo.
      TOKEN_PARAMETER_PREFIX = local.token_parameter_prefix
      # A repo is held until its build ends. The lease only matters when a build
      # dies without CodeBuild saying so, and then it frees the repo. It has to
      # cover the time a build can spend queued as well as running.
      LEASE_MINUTES = aws_codebuild_project.renovate.queued_timeout + aws_codebuild_project.renovate.build_timeout + 10
    }
  }

  depends_on = [aws_cloudwatch_log_group.orchestrator, aws_iam_role_policy_attachment.orchestrator]
}

resource "aws_cloudwatch_metric_alarm" "orchestrator_errors" {
  count               = var.failure_topic_arn != null ? 1 : 0
  alarm_name          = "renovate-orchestrator-errors"
  alarm_description   = "The orchestrator failed, so a request for a Renovate run may not have been acted on"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.orchestrator.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.failure_topic_arn]
}

# The orchestrator logs one JSON object per decision. The patterns match a
# phrase, because Lambda puts a timestamp and request ID in front of the line.
locals {
  orchestrator_log_metrics = {
    StartFailures   = "\"start failed\""
    SuspendedSweeps = "\"suspended\""
  }
}

resource "aws_cloudwatch_log_metric_filter" "orchestrator" {
  for_each = local.orchestrator_log_metrics

  name           = "renovate-orchestrator-${each.key}"
  log_group_name = aws_cloudwatch_log_group.orchestrator.name
  pattern        = each.value

  metric_transformation {
    name      = each.key
    namespace = "Renovate"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "start_failures" {
  count               = var.failure_topic_arn != null ? 1 : 0
  alarm_name          = "renovate-start-failures"
  alarm_description   = "The orchestrator has failed to start a Renovate build several times in half an hour"
  namespace           = "Renovate"
  metric_name         = "StartFailures"
  statistic           = "Sum"
  period              = 1800
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.failure_topic_arn]

  depends_on = [aws_cloudwatch_log_metric_filter.orchestrator]
}

# The sweep logs "suspended" every five minutes while the switch is on, so a
# sweep in each of 24 hours in a row means it has been left on for a day.
resource "aws_cloudwatch_metric_alarm" "left_suspended" {
  count               = var.failure_topic_arn != null ? 1 : 0
  alarm_name          = "renovate-left-suspended"
  alarm_description   = "Renovate has been suspended for a day, so nothing has started"
  namespace           = "Renovate"
  metric_name         = "SuspendedSweeps"
  statistic           = "Sum"
  period              = 3600
  evaluation_periods  = 24
  datapoints_to_alarm = 24
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.failure_topic_arn]

  depends_on = [aws_cloudwatch_log_metric_filter.orchestrator]
}
