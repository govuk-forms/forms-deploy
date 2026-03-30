variable "application_name" {
  type        = string
  description = "The name of the application being built"
}
variable "container_repository" {
  type        = string
  description = "Name of the container repository to write to. Assumed to be in the same account"
}

variable "source_repository" {
  type        = string
  description = "Name of the source repository in GitHub from which to get the Dockerfile. E.g. govuk-forms/forms-deploy"

  validation {
    condition     = can(regex("[A-Za-z0-9-_]+/[A-Za-z0-9-_]+", var.source_repository))
    error_message = "Source repository must be in the form org/repo"
  }
}

variable "codestar_connection_arn" {
  type        = string
  description = "The arn of the github connection to use"
}

variable "ecr_repository_url" {
  description = "The container repository URL from which image should be pulled"
  type        = string
  nullable    = false
}
