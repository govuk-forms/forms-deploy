allowed_account_ids = ["498160065950"]
deploy_account_id   = "711966560482"
account_name        = "dev"
default_tags = {
  Environment = "dev"
}
environment_name = "dev"
environment_type = "development"
environmental_settings = {
  auth0_domain                             = "govuk-forms-dev.uk.auth0.com"
  disable_auth0                            = false
  enable_auth0_splunk_log_stream           = false
  pause_databases_on_inactivity            = false
  pause_databases_after_inactivity_seconds = 300
  database_backup_retention_period_days    = 30
  allow_authentication_from_email_domains  = [".gov.uk"]
  enable_alert_actions                     = false
  forms_product_page_support_url           = "https://www.dev.forms.service.gov.uk/support"
  rds_maintenance_window                   = "wed:04:00-wed:04:30"
  ips_to_block                             = []
  rate_limit_bypass_cidrs                  = []
  enable_shield_advanced_healthchecks      = false
  allow_pagerduty_alerts                   = false
  redis_multi_az_enabled                   = false
  enable_advanced_database_insights        = false
}
root_domain = "dev.forms.service.gov.uk"
additional_dns_records = [
  # Records in support of MyNCSC Web Check
  {
    # Validation record for apex domain
    name    = "_asvdns-47a31c39-b1b1-4bc1-a841-732e38ca1968"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_16301d64-e65f-4747-9521-95ff3f595a10"]
  },
  {
    # Validation record for www. domain
    name    = "_asvdns-f85c83e0-a163-485e-a0e3-064baed6d6e4.www"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_cec80c72-e5ad-473d-b4c5-84ad2dd31b52"]
  },
  {
    # Validation record for admin. domain
    name    = "_asvdns-10cdf150-76bf-4e66-b377-ff9e169f9745.admin"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_c10fdf1c-3154-4c02-924c-6e0b75ab92ee"]
  },
  {
    # Validation record for submit. domain
    name    = "_asvdns-384e6e24-4f81-423a-95cf-a1dfe7f365ca.submit"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_02c14e81-d1c6-4360-bfbe-d6b07a019968"]
  },
  {
    # Validation record for api. domain
    name    = "_asvdns-efbc3d75-8753-4501-9e8e-2d31dc24cf80.api"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_6a94c72d-68ad-40b3-a79c-fd4451c6f4d7"]
  },
]
codestar_connection_arn = "arn:aws:codeconnections:eu-west-2:498160065950:connection/42243c20-40e2-467d-b135-999f91c37b55"
container_registry      = "711966560482.dkr.ecr.eu-west-2.amazonaws.com"
dlq_arn                 = "arn:aws:sqs:eu-west-2:711966560482:eventbridge-dead-letter-queue"
send_logs_to_cyber      = true
forms_admin_settings = {
  cpu                              = 256
  memory                           = 512
  min_capacity                     = 3
  max_capacity                     = 3
  enable_maintenance_mode          = false
  auth_provider                    = "auth0"
  previous_auth_provider           = null
  cloudwatch_metrics_enabled       = true
  analytics_enabled                = true
  enable_opentelemetry             = true
  opentelemetry_head_sampler_ratio = "0.1"
  act_as_user_enabled              = true
  govuk_app_domain                 = "integration.publishing.service.gov.uk"
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
  cpu                                                             = 512
  memory                                                          = 1024
  min_capacity                                                    = 3
  max_capacity                                                    = 3
  enable_maintenance_mode                                         = false
  cloudwatch_metrics_enabled                                      = true
  analytics_enabled                                               = true
  enable_opentelemetry                                            = true
  opentelemetry_head_sampler_ratio                                = "0.1"
  allow_human_readonly_roles_to_assume_submissions_to_s3_role     = true
  allow_human_readonly_roles_to_assume_submissions_to_runner_role = true
  ses_submission_email_from_email_address                         = "no-reply@dev.forms.service.gov.uk"
  ses_submission_email_reply_to_email_address                     = "no-reply@dev.forms.service.gov.uk"
  queue_worker_capacity                                           = 1
  disable_builtin_solidqueue_worker                               = true
  filler_answer_email_enabled                                     = false
}
scheduled_smoke_tests_settings = {
  enable_scheduled_smoke_tests = true
  form_url                     = "https://submit.dev.forms.service.gov.uk/form/11120/scheduled-smoke-test"
  frequency_minutes            = 10
  enable_alerting              = false
}
end_to_end_test_settings = {
  aws_s3_role_arn = "arn:aws:iam::498160065950:role/govuk-s3-end-to-end-test-dev"
  aws_s3_bucket   = "govuk-forms-submissions-to-s3-test"
  s3_form_id      = "12457"
}
