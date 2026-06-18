locals {
  scheduled_tasks = {
    mailchimp_sync = {
      enabled                   = var.enable_mailchimp_sync
      task_family               = "${var.env_name}_forms-admin_mailchimp_sync"
      schedule_expression       = "cron(30 10 * * ? *)"
      command                   = ["rake", "mailchimp:synchronize_audiences"]
      container_name            = "forms-admin_mailchimp_sync"
      log_stream_prefix         = "forms-admin-${var.env_name}-mailchimp-sync"
      schedule_rule_name        = "${var.env_name}-forms-admin-mailchimp-sync-cron"
      schedule_rule_description = "Trigger the forms-admin MailChimp synchronisation on a schedule"
      failure_alert = {
        rule_name_suffix = "mailchimp-sync-failed"
        description      = "Trigger when the MailChimp sync job has exited with a non-zero exit code"
        input_template   = <<EOF
    {
      "title": "WARNING: Synchronising mailing lists with MailChimp has failed.",
      "description": "GOV.UK Forms has a scheduled ECS task to sync our Mailchimp mailing list with new users in the users database (only applied in production). When this task fails an email is sent to Zendesk.",
      "next-steps": {
        "1": "Navigate to Splunk: https://gds.splunkcloud.com/en-GB/app/gds-543-forms/search.",
        "2": "Search for index=gds_dsp_production_forms log_stream=forms-admin-production-mailchimp-sync/forms-admin_mailchimp_sync/*. Use the 'Today' date-time preset to find today's logs.",
        "3": "Review logs for errors."
      }
    }
    EOF
      }
    }
    organisations_sync = {
      enabled                   = var.enable_organisations_sync
      task_family               = "${var.env_name}_forms-admin_organisations_sync"
      schedule_expression       = "cron(30 11 ? * TUE *)"
      command                   = ["rake", "organisations:fetch"]
      container_name            = "forms-admin_organisations_sync"
      log_stream_prefix         = "forms-admin-${var.env_name}-organisations-sync"
      schedule_rule_name        = "${var.env_name}-forms-admin-orgs-sync-cron"
      schedule_rule_description = "Trigger the forms-admin organisations synchronisation on a schedule"
      failure_alert = {
        rule_name_suffix = "org-sync-failed"
        description      = "Trigger when the organisations sync job has exited with a non-zero exit code"
        input_template   = <<EOF
    {
      "title": "WARNING: Synchronising organisations from GOV.UK has failed.",
      "description": "GOV.UK Forms has a scheduled ECS task to sync our organisations from GOV.UK. When this task fails an email is sent to Zendesk.",
      "next-steps": {
        "1": "Navigate to Splunk: https://gds.splunkcloud.com/en-GB/app/gds-543-forms/search.",
        "2": "Search for index=gds_dsp_production_forms log_stream=forms-admin-production-organisations-sync/forms-admin_organisations_sync/*. Use the 'Today' date-time preset to find today's logs.",
        "3": "Review logs for errors."
      }
    }
    EOF
      }
    }
  }
}

module "scheduled_tasks" {
  for_each = {
    for task_name, task in local.scheduled_tasks : task_name => task
    if task.enabled
  }
  source = "../ecs-scheduled-task"

  task_family                       = each.value.task_family
  container_name                    = each.value.container_name
  log_stream_prefix                 = each.value.log_stream_prefix
  schedule_rule_name                = each.value.schedule_rule_name
  schedule_rule_description         = each.value.schedule_rule_description
  schedule_expression               = each.value.schedule_expression
  command                           = each.value.command
  ecs_cluster_arn                   = var.ecs_cluster_arn
  scheduler_role_arn                = var.ecs_events_role_arn
  eventbridge_dead_letter_queue_arn = var.eventbridge_dead_letter_queue_arn
  base_task_container_definition    = module.ecs_service.task_container_definition
  application_log_group_name        = module.ecs_service.application_log_group_name
  execution_role_arn                = module.ecs_service.task_definition.execution_role_arn
  task_role_arn                     = module.ecs_service.task_definition.task_role_arn
  requires_compatibilities          = module.ecs_service.task_definition.requires_compatibilities
  cpu                               = var.cpu
  memory                            = var.memory
  network_security_groups           = module.ecs_service.service.network_configuration[0].security_groups
  network_subnets                   = module.ecs_service.service.network_configuration[0].subnets
  failure_alert = try(each.value.failure_alert, null) != null ? {
    rule_name      = "${var.env_name}-forms-admin-${each.value.failure_alert.rule_name_suffix}"
    description    = each.value.failure_alert.description
    input_template = each.value.failure_alert.input_template
  } : null
  zendesk_sns_topic_arn = try(each.value.failure_alert, null) != null ? var.zendesk_sns_topic_arn : null
}

moved {
  from = aws_ecs_task_definition.mailchimp_cron_job[0]
  to   = module.scheduled_tasks["mailchimp_sync"].aws_ecs_task_definition.this
}

moved {
  from = aws_cloudwatch_event_rule.sync_mailchimp_cron_job[0]
  to   = module.scheduled_tasks["mailchimp_sync"].aws_cloudwatch_event_rule.this
}

moved {
  from = aws_cloudwatch_event_target.ecs_mailchimp_sync_job[0]
  to   = module.scheduled_tasks["mailchimp_sync"].aws_cloudwatch_event_target.this
}

moved {
  from = aws_ecs_task_definition.orgs_cron_job[0]
  to   = module.scheduled_tasks["organisations_sync"].aws_ecs_task_definition.this
}

moved {
  from = aws_cloudwatch_event_rule.sync_orgs_cron_job[0]
  to   = module.scheduled_tasks["organisations_sync"].aws_cloudwatch_event_rule.this
}

moved {
  from = aws_cloudwatch_event_target.ecs_org_sync_job[0]
  to   = module.scheduled_tasks["organisations_sync"].aws_cloudwatch_event_target.this
}

moved {
  from = aws_cloudwatch_event_rule.sync_mailchimp_cron_job_failed
  to   = module.scheduled_tasks["mailchimp_sync"].aws_cloudwatch_event_rule.failed[0]
}

moved {
  from = aws_cloudwatch_event_target.sync_mailchimp_cron_job_alert_message
  to   = module.scheduled_tasks["mailchimp_sync"].aws_cloudwatch_event_target.failed_alert[0]
}

moved {
  from = aws_cloudwatch_event_rule.sync_orgs_cron_job_failed[0]
  to   = module.scheduled_tasks["organisations_sync"].aws_cloudwatch_event_rule.failed[0]
}

moved {
  from = aws_cloudwatch_event_target.sync_orgs_cron_job_alert_message[0]
  to   = module.scheduled_tasks["organisations_sync"].aws_cloudwatch_event_target.failed_alert[0]
}
