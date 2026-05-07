variable "environment_name" {
  description = "The name of the environment. This is distinct from the environment type, but is likely to share the same name in cases like production or staging."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.environment_name))
    error_message = "variable 'environment_name' must contain only alphanumeric characters, underscores, and hyphens; it must be a valid part of a DNS name"
  }
}

variable "environment_type" {
  description = "The type of environment this is. For example 'dev', 'staging', 'productions'."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["development", "staging", "production", "ithc"], var.environment_type)
    error_message = "variable 'environment_type' must be one of dev, staging, production, or ithc"
  }
}


variable "container_registry" {
  description = "The container registry from which images should be pulled"
  type        = string
  nullable    = false
}

variable "scheduled_smoke_tests_settings" {
  description = "Configuration for the scheduled smoke tests"
  type = object({
    enable_scheduled_smoke_tests = bool
    # This form is created specifically for the runner smoke tests. See https://github.com/alphagov/forms-e2e-tests/blob/main/spec/smoke_tests/smoke_test_runner_spec.rb
    form_url          = string
    frequency_minutes = number
    enable_alerting   = bool # Whether to send notification to govuk-forms-alerts channel
  })
}

variable "smoke_test_alarm_sns_topic_arn" {
  description = "The arn for the SNS topic that the smoke tests CloudWatch alarm will send notifications to."
  type        = string
}

variable "deploy_account_id" {
  type        = string
  description = "the account number for the deploy account"
}

variable "eventbridge_dead_letter_queue_url" {
  description = "The EventBridge dead letter queue URL where failed invocations are sent"
  type        = string
}
