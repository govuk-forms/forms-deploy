variable "deployment_name" {
  description = "Deployment to monitor (e.g., 'deploy', 'integration')"
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge schedule expression (e.g., 'cron(0 9 * * MON *)')"
  type        = string
}

variable "git_repository_url" {
  description = "Git repository URL to clone"
  type        = string
  default     = "https://github.com/govuk-forms/forms-deploy.git"
}

variable "git_branch" {
  description = "Git branch to check against"
  type        = string
  default     = "main"
}

variable "drift_detected_topic_arn" {
  description = "ARN of SNS topic to notify when drift is detected"
  type        = string
  default     = null
}
