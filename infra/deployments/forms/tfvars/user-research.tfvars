allowed_account_ids = ["619109835131"]
deploy_account_id   = "711966560482"
account_name        = "user-research"
default_tags = {
  Environment = "user-research"
}
environment_name = "user-research"
environment_type = "user_research"
environmental_settings = {
  auth0_domain                             = null
  disable_auth0                            = true
  enable_auth0_splunk_log_stream           = false
  pause_databases_on_inactivity            = true
  pause_databases_after_inactivity_seconds = 3600
  database_backup_retention_period_days    = 1
  allow_authentication_from_email_domains  = [] # user-research environment uses basic auth
  enable_alert_actions                     = false
  forms_product_page_support_url           = "https://www.research.forms.service.gov.uk/support"
  rds_maintenance_window                   = "wed:04:00-wed:04:30"
  ips_to_block                             = []
  rate_limit_bypass_cidrs                  = []
  enable_shield_advanced_healthchecks      = false
  allow_pagerduty_alerts                   = false
  redis_multi_az_enabled                   = false
  enable_advanced_database_insights        = false
}
root_domain             = "research.forms.service.gov.uk"
additional_dns_records  = []
codestar_connection_arn = "arn:aws:codeconnections:eu-west-2:619109835131:connection/056111d5-bc23-48a9-a159-ce767093ed9b"
container_registry      = "711966560482.dkr.ecr.eu-west-2.amazonaws.com"
dlq_arn                 = "arn:aws:sqs:eu-west-2:711966560482:eventbridge-dead-letter-queue"
send_logs_to_cyber      = true
forms_admin_settings = {
  cpu                              = 256
  memory                           = 512
  min_capacity                     = 0
  max_capacity                     = 0
  enable_maintenance_mode          = false
  auth_provider                    = "user_research"
  previous_auth_provider           = null
  cloudwatch_metrics_enabled       = false
  analytics_enabled                = false
  enable_opentelemetry             = false
  opentelemetry_head_sampler_ratio = "0.1"
  act_as_user_enabled              = false
  govuk_app_domain                 = ""
  synchronize_to_mailchimp         = false
  synchronize_orgs_from_govuk      = false
}
forms_product_page_settings = {
  cpu          = 256
  memory       = 512
  min_capacity = 3
  max_capacity = 3
}
forms_runner_settings = {
  cpu                                                             = 256
  memory                                                          = 512
  min_capacity                                                    = 0
  max_capacity                                                    = 0
  enable_maintenance_mode                                         = false
  cloudwatch_metrics_enabled                                      = false
  analytics_enabled                                               = false
  enable_opentelemetry                                            = false
  opentelemetry_head_sampler_ratio                                = "0.1"
  ses_submission_email_from_email_address                         = "no-reply@research.forms.service.gov.uk"
  ses_submission_email_reply_to_email_address                     = "no-reply@research.forms.service.gov.uk"
  allow_human_readonly_roles_to_assume_submissions_to_s3_role     = false
  allow_human_readonly_roles_to_assume_submissions_to_runner_role = false
  queue_worker_capacity                                           = 0
  disable_builtin_solidqueue_worker                               = true
  filler_answer_email_enabled                                     = false
}
scheduled_smoke_tests_settings = {
  enable_scheduled_smoke_tests = false
  form_url                     = "not-applicable"
  frequency_minutes            = 10
  enable_alerting              = false
}
end_to_end_test_settings = {
  # user research doesn't run e2e tests, but the module still needs something to be passed in here
  aws_s3_role_arn = ""
  aws_s3_bucket   = ""
  s3_form_id      = ""
}
