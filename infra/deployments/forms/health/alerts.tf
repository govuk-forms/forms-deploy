module "alerts" {
  source = "./alerts"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  environment                = var.environment_name
  minimum_healthy_host_count = 3
  enable_alert_actions       = var.environmental_settings.enable_alert_actions
  deploy_account_id          = var.deploy_account_id
  allow_pagerduty_alerts     = var.environmental_settings.allow_pagerduty_alerts


  zendesk_alert_topics = {
    us_east_1 : data.terraform_remote_state.forms_environment.outputs.zendesk_alert_us_east_1_topic_arn
    eu_west_2 : data.terraform_remote_state.forms_environment.outputs.zendesk_alert_eu_west_2_topic_arn
  }

  pagerduty_alert_topics = {
    eu_west_2 : data.terraform_remote_state.forms_environment.outputs.pagerduty_eu_west_2_topic_arn
  }


  auth0_email_bounces_and_complaints_queue_name      = data.terraform_remote_state.forms_ses.outputs.auth0_email_bounces_and_complaints_queue_name
  submission_email_bounces_and_complaints_dlq_name   = data.terraform_remote_state.forms_ses.outputs.submission_email_bounces_and_complaints_dlq_name
  confirmation_email_bounces_and_complaints_dlq_name = data.terraform_remote_state.forms_ses.outputs.confirmation_email_bounces_and_complaints_dlq_name
}
