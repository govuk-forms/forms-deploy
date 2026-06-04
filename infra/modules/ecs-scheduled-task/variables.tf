variable "task_name" {
  type        = string
  description = "The scheduled task name."
}

variable "schedule_expression" {
  type        = string
  description = "EventBridge schedule expression, for example cron(...) or rate(...)."
}

variable "command" {
  type        = list(string)
  description = "Container command override for the scheduled task."
}

variable "ecs_cluster_arn" {
  type        = string
  description = "ECS cluster ARN targeted by EventBridge."
}

variable "scheduler_role_arn" {
  type        = string
  description = "Shared IAM role ARN used by EventBridge to run ECS scheduled tasks."
}

variable "eventbridge_dead_letter_queue_arn" {
  type        = string
  description = "EventBridge dead-letter queue ARN."
}

variable "base_task_container_definition" {
  type        = any
  description = "Base container definition to clone from the app ECS service."
}

variable "application_log_group_name" {
  type        = string
  description = "CloudWatch Logs group name used by the task container."
}

variable "execution_role_arn" {
  type        = string
  description = "Execution role ARN for the ECS task definition."
}

variable "task_role_arn" {
  type        = string
  description = "Task role ARN for the ECS task definition."
}

variable "requires_compatibilities" {
  type        = list(string)
  description = "Task definition launch compatibilities."
}

variable "cpu" {
  type        = any
  description = "Task definition CPU value."
}

variable "memory" {
  type        = any
  description = "Task definition memory value."
}

variable "network_security_groups" {
  type        = list(string)
  description = "Security groups for the scheduled ECS task network config."
}

variable "network_subnets" {
  type        = list(string)
  description = "Subnets for the scheduled ECS task network config."
}

variable "platform_version" {
  type        = string
  description = "ECS Fargate platform version."
  default     = "1.4.0"
}
