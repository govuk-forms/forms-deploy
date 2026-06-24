variable "env_name" {
  type        = string
  description = "The name of the environment to be used in resource names."
}

variable "environment_type" {
  type        = string
  description = "The type of environment to be used."
}

variable "root_domain" {
  type        = string
  description = "The root domain for this deployment of GOV.UK Forms. For example: forms.service.gov.uk"
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

variable "admin_base_url" {
  type        = string
  description = "The url for redirecting to forms-admin"
}

variable "product_page_base_url" {
  type        = string
  description = "The url for redirecting to forms-product-page"
}

variable "api_base_url" {
  type        = string
  description = "The url for connecting to forms-admin"
}

variable "enable_maintenance_mode" {
  type        = bool
  description = "Controls whether the maintenance page is shown"
}

variable "maintenance_mode_bypass_ips" {
  type        = string
  description = "List of IP addresses which will bypass the maintenance mode message"
  default     = "213.86.153.211/32, 213.86.153.212/32, 213.86.153.213/32,213.86.153.214/32, 213.86.153.231/32, 213.86.153.235/32, 213.86.153.236/32, 213.86.153.237/32, 51.149.8.0/25, 51.149.8.128/29, 51.149.9.112/29, 51.149.9.240/29"
}

variable "rails_max_threads" {
  type        = number
  description = "The number of request threads run by the Puma server"
  default     = 25
}

variable "min_capacity" {
  type        = number
  description = "Sets the minimum number of instances"
}

variable "max_capacity" {
  type        = number
  description = "Sets the maximum number of instances"
}

variable "cloudwatch_metrics_enabled" {
  type        = bool
  description = "Enables metrics being sent to CloudWatch"
  default     = false
}

variable "analytics_enabled" {
  type        = bool
  description = "Enables Google analytics and the cookie banner"
  default     = false
}

variable "copy_of_answers_enabled" {
  type        = bool
  description = "Globally enables/disables asking people if they want a copy of their answers. If enabled, users are only asked if the form creator has enabled it for the form."
  default     = true
}

variable "deploy_account_id" {
  type        = string
  description = "the account number for the deploy account"
}

variable "additional_submissions_to_s3_role_assumers" {
  type        = list(string)
  description = "A list of role ARNs which are also allowed to assume the role for submissions to s3"
}

variable "additional_forms_runner_role_assumers" {
  type        = list(string)
  description = "A list of role ARNs which are also allowed to assume the role used to run forms-runner in ECS"
}

variable "ses_submission_email_from_email_address" {
  type        = string
  description = "The email address SES sends submission emails from"
}

variable "ses_submission_email_reply_to_email_address" {
  type        = string
  description = "The reply-to email address for submission emails send by SES"
}

variable "ses_submissions_configuration_set_name" {
  type        = string
  description = "The name of the configuration set to use when sending form submissions"
}

variable "ses_confirmations_configuration_set_name" {
  type        = string
  description = "The name of the configuration set to use when sending form confirmation emails"
}

variable "submission_bounces_and_complaints_sqs_queue_name" {
  type        = string
  description = "The name of the SQS queue to which SES sends notifications of bounces and complaints for submission emails"
}

variable "submission_deliveries_sqs_queue_name" {
  type        = string
  description = "The name of the SQS queue to which SES sends notifications of successful deliveries for submission emails"
}

variable "confirmation_bounces_and_complaints_sqs_queue_name" {
  type        = string
  description = "The name of the SQS queue to which SES sends notifications of bounces and complaints for confirmation emails"
}

variable "govuk_one_login_base_url" {
  type        = string
  description = "The base URL for GOV.UK One Login authentication requests"
}

variable "elasticache_port" {
  type        = number
  description = "The port number for the Redis ElastiCache cluster"
}

variable "elasticache_primary_endpoint_address" {
  type        = string
  description = "The Redis ElastiCache unique address used to by applications to connect to the database"
}

variable "container_repository" {
  type        = string
  description = "The name of the container repository to use"
}
variable "vpc_id" {
  type        = string
  description = "The VPC in which the service resides"
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block associated with the service's VPC"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "The list of private subnet ids used in the ECS service network configuration"
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
  description = "The ARN of the load balancer listener to which forms-runner will be attached"
}

variable "internal_alb_listener_arn" {
  type        = string
  description = "The ARN of the internal load balancer listener to which forms-runner will be attached for internal communication"
}

variable "send_logs_to_cyber" {
  type        = bool
  description = "Whether logs should be sent to cyber"
}

variable "submission_bounces_and_complaints_kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to decrypt messages on the submission bounces and complaints SQS queue"
}

variable "submission_deliveries_kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to decrypt messages on the submission deliveries SQS queue"
}

variable "confirmation_bounces_and_complaints_kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to decrypt messages on the confirmation email bounces and complaints SQS queue"
}

variable "queue_worker_capacity" {
  type        = number
  description = "Sets the desired number of tasks for the SolidQueue worker"
}

variable "disable_builtin_solidqueue_worker" {
  type        = bool
  description = "Ensure the built-in SolidQueue worker is disabled"
  default     = true
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

variable "filler_answer_email_enabled" {
  type        = bool
  description = "Enables the flag to send offer fillers an email containing the answers from a form submission"
  default     = false
}
