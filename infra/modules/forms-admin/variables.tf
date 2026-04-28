variable "env_name" {
  type        = string
  description = "The name of the environment to be used in resource names."
}

variable "root_domain" {
  type        = string
  description = "The root domain for this deployment of GOV.UK Forms. For example: forms.service.gov.uk"
}

variable "container_registry" {
  description = "The container registry from which images should be pulled"
  type        = string
  nullable    = false
}

variable "image_tag" {
  type     = string
  nullable = true
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}


variable "runner_base" {
  type        = string
  description = "The url for redirecting to forms-runner"
}

variable "auth_provider" {
  type        = string
  description = "Controls how users are authenticated"
  default     = "gds_sso"
}

variable "previous_auth_provider" {
  type        = string
  description = "The previous auth provider changing to preserve env vars and allow users to logout"
  default     = ""
}

variable "govuk_app_domain" {
  type        = string
  description = "The domain name for the Signon integration for auth flow"
  default     = ""
}

variable "enable_maintenance_mode" {
  type        = bool
  description = "Controls whether the maintenance page is shown"
}

variable "forms_product_page_support_url" {
  type        = string
  description = "Sets the support URL for the product page"
  default     = ""
}

variable "min_capacity" {
  description = "Sets the minimum number of instances"
  type        = number
}

variable "max_capacity" {
  description = "Sets the maximum number of instances"
  type        = number
}

variable "cloudwatch_metrics_enabled" {
  type        = bool
  description = "Enables metrics being sent to CloudWatch"
  default     = false
}

variable "analytics_enabled" {
  type        = bool
  description = "Enables Google analytics"
  default     = false
}

variable "act_as_user_enabled" {
  type        = bool
  description = "Enables act as user functionality for super admins"
  default     = false
}


variable "enable_mailchimp_sync" {
  type        = bool
  description = "Whether to synchronise the MailChimp mailing lists from the forms-admin user data"
  default     = false
}

variable "enable_organisations_sync" {
  type        = bool
  description = "Whether to synchronise the Organisations from GOV.UK data"
  default     = false
}

variable "deploy_account_id" {
  type        = string
  description = "the account number for the deploy account"
}

variable "vpc_id" {
  type        = string
  description = "The VPC in which the service resides"
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block associated with the service's VPC"
}

variable "eventbridge_dead_letter_queue_arn" {
  type        = string
  description = "The ARN of the EventBridge dead letter queue where Mailchimp sync failures are sent"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet ids used in the ECS service network configuration"
}

variable "zendesk_sns_topic_arn" {
  type        = string
  description = "The ARN of the Zendesk SNS topic where Mailchimp sync failures are sent (eu-west-2)"
}

variable "ecs_cluster_arn" {
  type        = string
  description = "The arn for the ECS cluster"
}

variable "alb_arn_suffix" {
  type        = string
  description = "The suffix of the Application Load Balancer ARN. Used with CloudWatch metrics"
}

variable "alb_listener_arn" {
  type        = string
  description = "The ARN of the load balancer listener to which forms-admin will be attached"
}

variable "internal_alb_listener_arn" {
  type        = string
  description = "The ARN of the internal load balancer listener to which forms-admin will be attached"
}

variable "cloudfront_secret" {
  type        = string
  description = "The secret header value that CloudFront sends to verify requests"
  sensitive   = true
}

variable "kinesis_subscription_role_arn" {
  description = "The arn of the role that is allowed to subscribe to the kinesis stream"
  type        = string
}

variable "enable_opentelemetry" {
  type        = bool
  description = "Enable AWS Distro for OpenTelemetry (ADOT) sidecar for distributed tracing to X-Ray"
  default     = false
}

variable "opentelemetry_head_sampler_ratio" {
  type        = string
  description = "Sampling ratio configuration in OpenTelemetry. This tells the Ruby SDK to sample spans such that only this ratio of traces gets exported. This assumes we are using a `TraceIdRatioBased` sampler. By default all spans are sampled"
  default     = "1"
}

variable "send_filler_answers" {
  type        = bool
  description = "enables the feature to send a filler's answers"
  default     = false
}
