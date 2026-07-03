variable "env_name" {
  type = string
}

variable "root_domain" {
  type        = string
  description = "The root domain for this deployment of GOV.UK Forms. For example: forms.service.gov.uk"
}

variable "sub_domain" {
  type        = string
  description = "The subdomain for this service."

  # We would like to validate that the sub_domain value ends with the root_domain value
  # but variable validation cannot refer to other variables prior to Terraform 1.9.
  #
  # When we are on Terraform 1.9, we should address this.
}

variable "internal_sub_domain" {
  type        = string
  description = "The internal subdomain for this service (e.g., admin.internal.forms.service.gov.uk)."
  nullable    = true
  default     = null
}

variable "listener_priority" {
  type        = number
  description = "The priority number for the load balancer listener rule that will be created. Numbers must be distinct across all invocations of this module in a deployment."
}

variable "include_domain_root_listener" {
  type        = bool
  description = "Whether an ALB listener should be created for the root domain as well as for the subdomain"
}

variable "application" {
  type        = string
  description = "The name of the application e.g. forms-admin"
  validation {
    condition     = contains(["forms-admin", "forms-runner", "forms-product-page"], var.application)
    error_message = "Valid values for application are: forms-admin, forms-runner, forms-product-page"
  }
}

variable "image" {
  type        = string
  description = "The image in ECR to deploy"
}

variable "cpu" {
  type        = string
  description = "The amount of CPU to provision in the ECS task."
}

variable "memory" {
  type        = string
  description = "The amount of memory to provision in the ECS task."
}

variable "readonly_root_filesystem" {
  type        = bool
  description = "Whether the task's root filesystem should be made readonly"
}

variable "environment_variables" {
  type        = list(any)
  description = "Environment variables to set in the task environment"
  default     = []
}

variable "secrets" {
  type        = list(any)
  description = "Secret values to look up form SSM Parameter store and set in the task environment"
  default     = []
}

variable "container_port" {
  type        = number
  description = "The port that the container process listens on."
}

variable "permit_internet_egress" {
  type        = bool
  description = "If true then the app's security group will permit egress to the internet on port 443"
  default     = false
}

variable "permit_postgres_egress" {
  type        = bool
  description = "If true then the app's security group will permit egress to the postgres on port 5432"
  default     = false
}

variable "permit_redis_egress" {
  type        = bool
  description = "If true then the app's security group will permit egress to the redis on port 6379"
  default     = false
}

variable "ecs_task_role_policy_json" {
  type        = string
  description = "JSON policy to be attached to the ECS task role"
  default     = ""
}

variable "additional_task_role_assumers" {
  type        = list(string)
  description = "The list of IAM role ARNs who should be trusted to assume the ECS task role"
  default     = []
}

variable "pre_deploy_script" {
  type        = string
  description = <<EOF
Absolute path to a script to run before a new task definition is run. Arguments are given as environment variables

ECS_CLUSTER_ARN: The ECS cluster ARN
ECS_TASK_DEFINITION_ARN: The task definition ARN
ECS_TASK_NETWORK_CONFIGURATION: The network configuration to use when running the task
CONTAINER_DEFINITION_JSON: The task's container definition in JSON

If left empty, no script will be run.
EOF
  default     = ""
}

variable "scaling_rules" {
  type = object({
    min_capacity                                = number
    max_capacity                                = number
    p95_response_time_scaling_threshold_seconds = number
    scale_in_cooldown                           = number
    scale_out_cooldown                          = number
  })
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID in which the ECS services reside"
}

variable "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "The list of private subnet ids used in the ECS service network configuration"
}

variable "alb_arn_suffix" {
  type        = string
  description = "The suffix of the Application Load Balancer ARN. Used with CloudWatch metrics"
}

variable "alb_listener_arn" {
  type        = string
  description = "The ARN of the load balancer listener to which the application will be attached"
}

variable "internal_alb_listener_arn" {
  type        = string
  description = "The ARN of the internal load balancer listener to which the application will be attached"
  nullable    = true
  default     = null
}

variable "ecs_cluster_arn" {
  type        = string
  description = "The arn for the ECS cluster"
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
  description = "Enable AWS Distro for OpenTelemetry (ADOT) collector sidecar and enable OpenTelemetry in the application"
  default     = false
}

variable "adot_sidecar_cpu" {
  type        = number
  description = "CPU units to allocate to ADOT sidecar (default: 256 = 0.25 vCPU)"
  default     = 256
}

variable "adot_sidecar_memory" {
  type        = number
  description = "Memory in MB to allocate to ADOT sidecar"
  default     = 512
}

variable "adot_collector_config" {
  type        = string
  description = "ADOT collector configuration file path. By default this uses the ECS-provided config at /etc/ecs/ecs-default-config.yaml, which enables basic trace collection and export to AWS X-Ray using the AWS Distro for OpenTelemetry (ADOT) defaults (including receivers, exporters, and sampling configuration managed by AWS)."
  default     = "/etc/ecs/ecs-default-config.yaml"
}

variable "adot_image" {
  type        = string
  description = "ADOT collector container image URI"
  default     = "public.ecr.aws/aws-observability/aws-otel-collector:v0.48.0" # Latest as-of 2026-05-21
}

variable "opentelemetry_head_sampler_ratio" {
  type        = string
  description = "Sampling ratio configuration in OpenTelemetry. This tells the Ruby SDK to sample spans such that only this ratio of traces gets exported. This assumes we are using a `TraceIdRatioBased` sampler. By default all spans are sampled"
  default     = "1"
}

variable "healthcheck" {
  type = object({
    command     = list(string)
    interval    = number
    timeout     = optional(number)
    retries     = number
    startPeriod = number
  })
  description = "The health check configuration for the ECS task. If not provided, the task will not have a health check configured."
  default     = null
}
