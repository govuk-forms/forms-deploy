##
# Task role: what Grafana itself may do
##
resource "aws_iam_role" "task" {
  name               = "${local.name}-ecs-task"
  description        = "Used by Grafana tasks when running"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    sid     = "AllowECS"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "task" {
  #checkov:skip=CKV_AWS_355:CloudWatch and X-Ray read operations cannot be scoped to specific resources
  #checkov:skip=CKV_AWS_356:CloudWatch and X-Ray read operations cannot be scoped to specific resources
  name   = "${local.name}-ecs-task-policy"
  policy = data.aws_iam_policy_document.task.json
}

resource "aws_iam_role_policy_attachment" "task" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task.arn
}

data "aws_iam_policy_document" "task" {
  #checkov:skip=CKV_AWS_356:"*" is necessary here, and all of the actions are read-only.

  # https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/configure/
  #
  # GetMetricData and ListMetrics also authorise the CloudWatch PromQL endpoint
  # (https://monitoring.<region>.amazonaws.com/api/v1/*) that the Amazon
  # Managed Service for Prometheus data source queries OTLP metrics through, see
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-PromQL.html#CloudWatch-PromQL-IAM
  statement {
    sid    = "ReadCloudWatchMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetInsightRuleReport",
      "pi:GetResourceMetrics"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:ListAggregateLogGroupSummaries",
      "logs:GetLogGroupFields",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadResourceMetadataForDataSources"
    effect = "Allow"
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "tag:GetResources",
      "oam:ListSinks",
      "oam:ListAttachedLinks"
    ]
    resources = ["*"]
  }

  # https://grafana.com/docs/plugins/grafana-x-ray-datasource/latest/configure/
  statement {
    sid    = "ReadXRayAndApplicationSignals"
    effect = "Allow"
    actions = [
      "xray:BatchGetTraces",
      "xray:GetTraceSummaries",
      "xray:GetTraceGraph",
      "xray:GetGroups",
      "xray:GetTimeSeriesServiceStatistics",
      "xray:GetInsightSummaries",
      "xray:GetInsight",
      "xray:GetServiceGraph",
      "xray:GetSamplingRules",
      "application-signals:ListServices",
      "application-signals:ListServiceOperations",
      "application-signals:ListServiceDependencies",
      "application-signals:ListServiceLevelObjectives",
      "application-signals:GetService",
      "application-signals:GetServiceLevelObjective"
    ]
    resources = ["*"]
  }
}

##
# Execution role: what ECS needs to start the task
##
resource "aws_iam_role" "task_execution" {
  name               = "${local.name}-ecs-task-execution"
  description        = "Used by ECS to create Grafana tasks"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "task_execution_standard" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "task_execution_additional" {
  name   = "${local.name}-ecs-task-execution-additional"
  policy = data.aws_iam_policy_document.task_execution_additional.json
}

resource "aws_iam_role_policy_attachment" "task_execution_additional" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.task_execution_additional.arn
}

data "aws_iam_policy_document" "task_execution_additional" {
  statement {
    sid     = "ReadSecrets"
    effect  = "Allow"
    actions = ["ssm:GetParameters"]
    resources = [
      aws_ssm_parameter.database_password.arn,
      aws_ssm_parameter.admin_password.arn,
      aws_ssm_parameter.secret_key.arn,
      aws_ssm_parameter.github_client_id.arn,
      aws_ssm_parameter.github_client_secret.arn
    ]
  }
}
