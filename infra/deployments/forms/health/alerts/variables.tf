variable "environment" {
  type        = string
  description = "The name of the environment to be used in resource names."
}

variable "minimum_healthy_host_count" {
  type        = number
  description = "Alert will trigger if the minimum healthy host count for any ECS service drops below this number. Leaving at 0 effectively disables this alert."
  default     = 0
}

variable "enable_alert_actions" {
  type        = bool
  description = "Whether the alerts carry out the actions, for example, notifying us via Slack"
  default     = true
}

variable "deploy_account_id" {
  type        = string
  description = "the account number for the deploy account"
}

variable "zendesk_alert_topics" {
  type = object({
    us_east_1 : string
    eu_west_2 : string
  })

  description = "The ARNs of the SNS topics to use to send an alert to Zendesk, per region"

  validation {
    condition     = alltrue([for p, arn in tomap(var.zendesk_alert_topics) : can(provider::aws::arn_parse(arn))])
    error_message = "All values must be valid ARNs"
  }
}

variable "pagerduty_alert_topics" {
  type = object({
    eu_west_2 : string
  })

  description = "The ARNs of the SNS topics to use to send an alert to PagerDuty, per region"

  validation {
    condition     = alltrue([for p, arn in tomap(var.pagerduty_alert_topics) : can(provider::aws::arn_parse(arn))])
    error_message = "All values must be valid ARNs"
  }
}

variable "allow_pagerduty_alerts" {
  type        = bool
  description = "Whether alerts should be allowed to go to PagerDuty at all"
}

variable "auth0_email_bounces_and_complaints_queue_name" {
  type        = string
  description = "The name of the SQS queue for Auth0 email bounces and complaints"
}
variable "submission_email_bounces_and_complaints_dlq_name" {
  type        = string
  description = "The name of the SQS queue for dead letters on the submission emails bounces and complaints queue"
}

variable "confirmation_email_bounces_and_complaints_dlq_name" {
  type        = string
  description = "The name of the SQS queue for dead letters on the confirmation emails bounces and complaints queue"
}

variable "form_confirmations_configuration_set_name" {
  description = "SES configuration set name for form confirmation emails"
  type        = string
}
