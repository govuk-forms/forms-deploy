##
# Naming
##
variable "environment_type" {
  description = "The type of environment this is. For example 'dev', 'staging', 'production'."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["development", "staging", "production", "user_research", "ithc"], var.environment_type)
    error_message = "variable 'environment_type' must be one of dev, staging, production, user_research, or ithc"
  }
}

variable "environment_name" {
  description = "The name of the environment. This is distinct from the environment type, but is likely to share the same name in cases like production or staging."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.environment_name))
    error_message = "variable 'environment_name' must contain only alphanumeric characters, underscores, and hyphens; it must be a valid part of a DNS name"
  }
}

variable "account_name" {
  description = "The name of the account. For example 'dev', 'staging', 'production'. This is distinct from the environment name, but will sometimes be the same value."
  type        = string
  nullable    = false
}

##
# Infra
##
variable "codestar_connection_arn" {
  description = "It isn't possible to automate the creation of a CodeStar connection, so we must create it by hand once in each account and hardcode its ARN."
  type        = string
  nullable    = false
}

variable "container_registry" {
  description = "The container registry from which images should be pulled"
  type        = string
  nullable    = false
}

variable "deploy_account_id" {
  description = "the account number for deploy account"
  type        = string
  nullable    = false
}

variable "bucket" {
  description = "Name of the state file bucket. This is named to match the key in the S3 type backend"
  type        = string
  nullable    = false
}

variable "dlq_arn" {
  description = "The ARN of the dead letter queue for paused pipeline detection"
  type        = string
  nullable    = false
}

variable "send_logs_to_cyber" {
  description = "Whether logs should be sent to cyber"
  type        = bool
}

##
# AWS provider
##
variable "allowed_account_ids" {
  description = <<EOF
The list of AWS account ids to be allowed for this Terraform application.
This prevents us from applying one environment configuration to the wrong account(s)."
EOF
  type        = list(string)
  nullable    = false
}

variable "default_tags" {
  description = "The set of tags which should be attached to every resource by default."
  type        = map(string)
  nullable    = false
}

##
# DNS
##
variable "root_domain" {
  description = "The root domain under which the environment will be deployed"
  type        = string
  nullable    = false
}

variable "additional_dns_records" {
  description = <<EOF
Additional DNS records to set in the environment. Some environments have DNS records that must be set, which other environments don't need.

Record names should be limited the subdomain portion of the name. They will be suffixed with the value of the root_domain variable.

To add records for the root domain, set name to the empt string.
EOF
  type = list(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))

  validation {
    condition     = alltrue([for r in var.additional_dns_records : !endswith(r.name, ".")])
    error_message = "DNS record names must not end with a dot"
  }

  validation {
    condition     = alltrue([for r in var.additional_dns_records : (length(r.records) > 0)])
    error_message = "All DNS records must have at least 1 value in the records list"
  }

  validation {
    condition     = length([for r in var.additional_dns_records : [r.name, r.type]]) == length(distinct([for r in var.additional_dns_records : [r.name, r.type]]))
    error_message = "All DNS record name must be unique for a given type. If you need to add another value, add the value to its records list"
  }
}

##
# Settings
##
variable "forms_admin_settings" {
  description = "Forms Admin configuration values"
  type = object({
    cpu                              = number
    memory                           = number
    min_capacity                     = number
    max_capacity                     = number
    enable_maintenance_mode          = bool
    auth_provider                    = string
    previous_auth_provider           = string
    cloudwatch_metrics_enabled       = bool
    analytics_enabled                = bool
    enable_opentelemetry             = optional(bool, false)
    opentelemetry_head_sampler_ratio = string
    act_as_user_enabled              = bool
    govuk_app_domain                 = string
    synchronize_to_mailchimp         = bool
    synchronize_orgs_from_govuk      = bool
    send_filler_answers              = bool
  })
  nullable = false
}

variable "forms_product_page_settings" {
  description = "Forms Product Page configuration values"
  type = object({
    cpu          = number
    memory       = number
    min_capacity = number
    max_capacity = number
  })
}

variable "forms_runner_settings" {
  description = "Forms Runner configuration values"
  type = object({
    cpu                                                             = number
    memory                                                          = number
    min_capacity                                                    = number
    max_capacity                                                    = number
    enable_maintenance_mode                                         = bool
    cloudwatch_metrics_enabled                                      = bool
    analytics_enabled                                               = bool
    enable_opentelemetry                                            = optional(bool, false)
    opentelemetry_head_sampler_ratio                                = string
    allow_human_readonly_roles_to_assume_submissions_to_s3_role     = bool
    allow_human_readonly_roles_to_assume_submissions_to_runner_role = bool
    ses_submission_email_from_email_address                         = string
    ses_submission_email_reply_to_email_address                     = string
    queue_worker_capacity                                           = string
    disable_builtin_solidqueue_worker                               = bool
    filler_answer_email_enabled                                     = bool
  })
}

variable "environmental_settings" {
  description = "Configuration values for the environment. The types of settings that affect the environment as a whole, and aren't specific to one application."
  type = object({
    auth0_domain                             = string
    disable_auth0                            = bool
    enable_auth0_splunk_log_stream           = bool
    pause_databases_on_inactivity            = bool
    pause_databases_after_inactivity_seconds = number
    database_backup_retention_period_days    = number
    allow_authentication_from_email_domains  = list(string)
    enable_alert_actions                     = bool
    forms_product_page_support_url           = string
    rds_maintenance_window                   = string
    ips_to_block                             = list(string)
    rate_limit_bypass_cidrs                  = list(string)
    enable_shield_advanced_healthchecks      = bool
    allow_pagerduty_alerts                   = bool
    redis_multi_az_enabled                   = bool
    enable_advanced_database_insights        = bool
  })
}

variable "scheduled_smoke_tests_settings" {
  description = "Configuration for the scheduled smoke tests"
  type = object({
    enable_scheduled_smoke_tests = bool
    form_url                     = string # This form is created specifically for the runner smoke tests. See https://github.com/govuk-forms/forms-e2e-tests/blob/main/spec/smoke_tests/smoke_test_runner_spec.rb
    frequency_minutes            = number
    enable_alerting              = bool # Whether to send notification to govuk-forms-alerts channel
  })
}

variable "end_to_end_test_settings" {
  description = "Configuration for the end to end tests"
  type = object({
    aws_s3_role_arn = string
    aws_s3_bucket   = string
    s3_form_id      = string
  })
}
