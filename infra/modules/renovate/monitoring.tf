# Renovate's JSON logs have a numeric level: 20 is debug, 30 info, 40 warn and
# 50 error. A line without a repository field can't give a per-repository
# metric, so those patterns also require the field, and the counts that must
# never miss a line have no dimension.
locals {
  build_log_metrics = {
    LogErrors   = { pattern = "{ $.level >= 50 }", by_repository = false }
    LogWarnings = { pattern = "{ $.level = 40 }", by_repository = false }

    PullRequestsCreated   = { pattern = "{ ($.level = 30) && ($.msg = \"PR created\") && ($.repository = *) }", by_repository = true }
    PullRequestsUpdated   = { pattern = "{ ($.level = 30) && ($.msg = \"PR updated\") && ($.repository = *) }", by_repository = true }
    AbandonedDependencies = { pattern = "{ ($.level = 20) && ($.msg = \"Package abandonment detected*\") && ($.repository = *) }", by_repository = true }
  }
}

resource "aws_cloudwatch_log_metric_filter" "build" {
  for_each = local.build_log_metrics

  name           = "renovate-${each.key}"
  log_group_name = aws_cloudwatch_log_group.renovate.name
  pattern        = each.value.pattern

  metric_transformation {
    name       = each.key
    namespace  = "Renovate"
    value      = "1"
    unit       = "Count"
    dimensions = each.value.by_repository ? { Repository = "$.repository" } : null
  }
}

resource "aws_cloudwatch_metric_alarm" "log_errors" {
  count               = var.failure_topic_arn != null ? 1 : 0
  alarm_name          = "renovate-log-errors"
  alarm_description   = "Renovate logged an error, even if the build succeeded"
  namespace           = "Renovate"
  metric_name         = "LogErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.failure_topic_arn]

  depends_on = [aws_cloudwatch_log_metric_filter.build]
}
