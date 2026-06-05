allowed_account_ids = ["443944947292"]
deploy_account_id   = "711966560482"
account_name        = "production"
default_tags = {
  Environment = "production"
}
environment_name = "production"
environment_type = "production"
environmental_settings = {
  auth0_domain                             = "govuk-forms.uk.auth0.com"
  disable_auth0                            = false
  enable_auth0_splunk_log_stream           = true
  pause_databases_on_inactivity            = false
  pause_databases_after_inactivity_seconds = 60 * 60 * 24
  # Set to 24 hours for inactivity just in case the pause_database_on_inactivity flag is inverted or ignored
  database_backup_retention_period_days = 30
  enable_alert_actions                  = true
  enable_slo_burn_rate_alert_actions    = true
  allow_authentication_from_email_domains = [
    ".gov.scot",
    ".gov.uk",
    ".gov.wales",
    ".mod.uk",
    "@cefas.co.uk",
    "@certoffice.org",
    "@ddc-mod.org",
    "@hs2.org.uk",
    "@innovateuk.ukri.org",
    "@mod.uk",
    "@nationalhighways.co.uk",
    "@naturalengland.org.uk",
    "@slc.co.uk",
    "@ukces.org.uk",
    "@ukri.org",
    "@dounreay.com",
    "@marinemanagement.org.uk",
    "@gov.scot",
    "@gov.wales",
    "@dhsc.egresscloud.com",
    "@acas.org.uk"
  ]
  forms_product_page_support_url      = "https://www.forms.service.gov.uk/support"
  rds_maintenance_window              = "wed:04:00-wed:04:30"
  rds_minimum_capacity_acus           = 2
  rds_maxium_capacity_acus            = 10
  ips_to_block                        = []
  rate_limit_bypass_cidrs             = []
  enable_shield_advanced_healthchecks = true
  allow_pagerduty_alerts              = true
  redis_multi_az_enabled              = true
  enable_advanced_database_insights   = true
}
root_domain = "forms.service.gov.uk"
additional_dns_records = [
  # Records in support of MyNCSC Web Check
  {
    # Validation record for apex domain
    name    = "_asvdns-3135bcc2-f3a6-4575-99e3-107b802607ab"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_ba7549ac-6142-4838-a85d-aad0cd4e3238"]
  },
  {
    # Validation record for submit.
    name    = "_asvdns-677c95c4-4883-49c1-aaaf-d5d357de6214.submit"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_1562e193-1dda-4dff-b80f-30a51d40f9fa"]
  },
  {
    # Validation record for admin.
    name    = "_asvdns-7ccd9131-fdea-4bcf-9ee3-980f751ccff6.admin"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_c563af35-dcf1-40c6-b2c0-bc2719a2c2fc"]
  },
  {
    # Validation record for www.
    name    = "_asvdns-b4f022ae-7033-40d5-bd61-1465c9ea5a30.www"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_61809fb0-4bf0-4e8e-82e2-e6febfba9faa"]
  },
  {
    # Validation record for api.
    name    = "_asvdns-453532a6-2653-4d64-a5b2-8bd02812ccea.api"
    type    = "TXT"
    ttl     = 86400
    records = ["asvdns_1d96d003-5726-4840-b265-4b5f6e08094a"]
  },


  # DMARC records from MyNCSC
  {
    # DMARC reporting record for apex domain
    name    = "_dmarc"
    type    = "TXT"
    ttl     = 86400
    records = ["v=DMARC1; p=quarantine; pct=100; rua=mailto:dmarc-rua@dmarc.service.gov.uk;"]
  },
  {
    # DMARC reporting record for submit.
    name    = "_dmarc.submit"
    type    = "TXT"
    ttl     = 86400
    records = ["v=DMARC1; p=quarantine; pct=100; rua=mailto:dmarc-rua@dmarc.service.gov.uk;"]
  },

  # TLS-RPT records from MyNCSc
  {
    name    = "_stmp._tls"
    type    = "TXT"
    ttl     = 86400
    records = ["v=TLSRPTv1;rua=mailto:tls-rua@mailcheck.service.ncsc.gov.uk"]
  },

  # CNAME record for Statuspage custom domain
  {
    name    = "status"
    type    = "CNAME"
    ttl     = 86400
    records = ["pk3kdktj7wwp.stspg-customer.com"]
  }
]
codestar_connection_arn = "arn:aws:codeconnections:eu-west-2:443944947292:connection/a2c94a66-2c03-45db-bb18-5c37f8b44531"
container_registry      = "711966560482.dkr.ecr.eu-west-2.amazonaws.com"
dlq_arn                 = "arn:aws:sqs:eu-west-2:711966560482:eventbridge-dead-letter-queue"
send_logs_to_cyber      = true
forms_admin_settings = {
  cpu                              = 512
  memory                           = 1024
  min_capacity                     = 6
  max_capacity                     = 36
  enable_maintenance_mode          = false
  auth_provider                    = "auth0"
  previous_auth_provider           = null
  cloudwatch_metrics_enabled       = true
  analytics_enabled                = true
  enable_opentelemetry             = true
  opentelemetry_head_sampler_ratio = "0.1"
  act_as_user_enabled              = false
  govuk_app_domain                 = "publishing.service.gov.uk"
  synchronize_to_mailchimp         = true
  synchronize_orgs_from_govuk      = true
  send_filler_answers              = false
}
forms_product_page_settings = {
  cpu          = 256
  memory       = 512
  min_capacity = 3
  max_capacity = 9
}
forms_runner_settings = {
  cpu                                                             = 1024
  memory                                                          = 2048
  min_capacity                                                    = 6
  max_capacity                                                    = 36
  enable_maintenance_mode                                         = false
  cloudwatch_metrics_enabled                                      = true
  analytics_enabled                                               = true
  enable_opentelemetry                                            = true
  opentelemetry_head_sampler_ratio                                = "0.1"
  allow_human_readonly_roles_to_assume_submissions_to_s3_role     = false
  allow_human_readonly_roles_to_assume_submissions_to_runner_role = false
  ses_submission_email_from_email_address                         = "no-reply@forms.service.gov.uk"
  ses_submission_email_reply_to_email_address                     = "no-reply@forms.service.gov.uk"
  govuk_one_login_base_url                                        = "https://oidc.account.gov.uk/"
  queue_worker_capacity                                           = 6
  disable_builtin_solidqueue_worker                               = true
  filler_answer_email_enabled                                     = false
}
scheduled_smoke_tests_settings = {
  enable_scheduled_smoke_tests = true
  form_url                     = "https://submit.forms.service.gov.uk/form/2570/scheduled-smoke-test"
  frequency_minutes            = 10
  enable_alerting              = true
}
end_to_end_test_settings = {
  aws_s3_role_arn = "arn:aws:iam::443944947292:role/govuk-s3-end-to-end-test-production"
  aws_s3_bucket   = "govuk-forms-submissions-to-s3-test"
  s3_form_id      = "5086"
}
