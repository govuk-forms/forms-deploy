variable "schedule_expression" {
  description = "EventBridge schedule expression for the Renovate run"
  type        = string
}

variable "github_organisation" {
  description = "GitHub organisation the Renovate GitHub App is installed on"
  type        = string
  default     = "govuk-forms"
}

variable "repositories" {
  description = "Repositories Renovate runs against, as owner/name. Add a repo here only once the GitHub App is installed on it."
  type        = list(string)
  default     = ["govuk-forms/forms-deploy"]
}

variable "dry_run" {
  description = "Renovate's dryRun mode: extract, lookup or full. Null makes Renovate open real branches and pull requests."
  type        = string
  default     = "full"

  validation {
    condition     = var.dry_run == null || contains(["extract", "lookup", "full"], coalesce(var.dry_run, "null"))
    error_message = "dry_run must be one of extract, lookup or full, or null to run for real."
  }
}

variable "renovate_image" {
  description = "Renovate container image, pinned by digest"
  type        = string
  default     = "ghcr.io/renovatebot/renovate:44.199.2@sha256:0538f498be1b074e2434f8449cab7b2be30f8c0d0baf3b72814010f19db5bcfb"
}

variable "failure_topic_arn" {
  description = "ARN of an SNS topic to notify when a Renovate run fails"
  type        = string
  default     = null
}
