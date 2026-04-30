resource "aws_ssm_parameter" "notify_api_key" {
  #checkov:skip=CKV_AWS_337:KMS managed key is fine
  name  = "/forms-runner-${var.env_name}/notify-api-key"
  type  = "SecureString"
  value = "dummy_value"

  description = "API key to connect with GOV.UK Notify"

  lifecycle {
    ignore_changes = [value]
  }
}

# Secret Key Base
# Rails uses secret_key_base as the input secret to the application's key generator.
# We use this mostly for cookies, and we create and store one per app
# This secret stores a manually generated random value. As an example, you can generate a new one by running:
# ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
resource "aws_ssm_parameter" "secret_key_base" {
  #checkov:skip=CKV_AWS_337:KMS managed key is fine

  name        = "/forms-runner-${var.env_name}/secret-key-base"
  description = "Rails secret_key_base value for forms-runner in the ${var.env_name} environment"
  type        = "SecureString"
  value       = "dummy-value"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

# Sentry Data Source Name (DSN)
# This value tells Sentry where to send events to that they are associated with the correct project
resource "aws_ssm_parameter" "sentry_dsn" {
  #checkov:skip=CKV_AWS_337:KMS managed key is fine

  name        = "/forms-runner-${var.env_name}/sentry/dsn"
  description = "Sentry DSN value for forms-runner in the ${var.env_name} environment"
  type        = "SecureString"
  value       = "dummy-value"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

# GOV.UK One Login client ID
# The client ID for the GOV.UK One Login service
resource "aws_ssm_parameter" "govuk_one_login_client_id" {
  #checkov:skip=CKV_AWS_337:KMS managed key is fine

  name        = "/forms-runner-${var.env_name}/govuk-one-login/client-id"
  description = "The GOV.UK One Login client ID for forms-runner in the ${var.env_name} environment"
  type        = "SecureString"
  value       = "dummy-value"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

# GOV.UK One Login private key
# The base64 encoded private key for the GOV.UK One Login service
resource "aws_ssm_parameter" "govuk_one_login_private_key" {
  #checkov:skip=CKV_AWS_337:KMS managed key is fine

  name        = "/forms-runner-${var.env_name}/govuk-one-login/private-key"
  description = "The base64 encoded GOV.UK One Login private key for forms-runner in the ${var.env_name} environment"
  type        = "SecureString"
  value       = "dummy-value"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
