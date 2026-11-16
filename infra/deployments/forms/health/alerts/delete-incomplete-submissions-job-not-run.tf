resource "aws_cloudwatch_metric_alarm" "delete_incomplete_submissions_job_not_run" {
  alarm_name          = "${var.environment}-delete-incomplete-submissions-job-not-run"
  alarm_description   = <<EOF
    The forms-runner job to delete incomplete submissions has not run in the ${var.environment} environment in the past 2
    hours. It is expected that the job is run every hour. This job is run by Solid Queue, which is started in the
    forms-runner-queue-worker ECS task.

    NEXT STEPS:
    1. Check the Splunk logs and Sentry for any errors running the job.
    2. Restart the forms-runner-queue-worker ECS tasks and check whether the job starts running.

EOF
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Started"
  namespace           = "Forms/Jobs"
  period              = 7200
  statistic           = "SampleCount"
  threshold           = 0

  dimensions = {
    Environment = "${var.environment}"
    ServiceName = "forms-runner"
    JobName     = "DeleteIncompleteSubmissionsJob"
  }

  treat_missing_data = "breaching"

  alarm_actions = [local.alert_severity.eu_west_2.info]
  ok_actions    = [local.alert_severity.eu_west_2.info]
}
