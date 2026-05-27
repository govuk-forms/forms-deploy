variable "environment_name" {
  type = string
}

variable "container_registry" {
  description = "The container registry from which images should be pulled"
  type        = string
  nullable    = false
}

variable "app_name" {
  type        = string
  description = "The name of the application e.g. forms-admin"
  validation {
    condition     = contains(["forms-admin", "forms-runner", "forms-product-page", "post-terraform-apply"], var.app_name)
    error_message = "Valid values for app_name are: forms-admin, forms-runner, forms-product-page"
  }
}

variable "artifact_store_arn" {
  type        = string
  description = "An S3 bucket arn where artifacts can be stored"
}

variable "forms_admin_url" {
  type        = string
  description = "The url for forms admin"
}

variable "product_pages_url" {
  type        = string
  description = "The url for the product pages"
}

variable "forms_runner_url" {
  type        = string
  description = "The url for forms runner"
}

variable "codestar_connection_arn" {
  type        = string
  description = "the arn of the deploy account github connection"
}

variable "auth0_user_name_parameter_name" {
  type        = string
  description = "The parameter name for the username for Auth0 login into forms-admin"
}

variable "auth0_user_password_parameter_name" {
  type        = string
  description = "The parameter name for the password for Auth0 login into forms-admin"
}

variable "notify_api_key_parameter_name" {
  type        = string
  description = "The parameter name for the Notify API key to use when checking for form submissions"
}

variable "service_role_arn" {
  type        = string
  description = "The ARN of the IAM role for the CodeBuild service"
  nullable    = false
}

variable "deploy_account_id" {
  type        = string
  description = "The account number for deploy account"
  nullable    = false
}

variable "aws_s3_role_arn" {
  type        = string
  description = "The arn of the role which has permissions to submit to the s3 bucket"
}

variable "aws_s3_bucket" {
  type        = string
  description = "The s3 bucket where test forms are sent"
}

variable "s3_form_id" {
  type        = string
  description = "The id of the form that you want to run the s3 submission type end to end tests against"
}
