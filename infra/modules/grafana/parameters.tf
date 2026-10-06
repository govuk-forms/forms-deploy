resource "random_password" "database" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "database_password" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  #checkov:skip=CKV2_FORMS_AWS_7:We know the correct value at runtime and should not ignore changes to it
  name        = "${local.ssm_prefix}/database/password"
  description = "Master password for the Grafana database"
  type        = "SecureString"
  value       = random_password.database.result
}

resource "random_password" "admin" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "admin_password" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  #checkov:skip=CKV2_FORMS_AWS_7:We know the correct value at runtime and should not ignore changes to it
  name        = "${local.ssm_prefix}/admin-password"
  description = "Password for the built-in Grafana admin user, for use when GitHub login is unavailable"
  type        = "SecureString"
  value       = random_password.admin.result
}

resource "random_password" "secret_key" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "secret_key" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  #checkov:skip=CKV2_FORMS_AWS_7:We know the correct value at runtime and should not ignore changes to it
  name        = "${local.ssm_prefix}/secret-key"
  description = "Key Grafana uses to encrypt data source credentials at rest"
  type        = "SecureString"
  value       = random_password.secret_key.result
}

resource "aws_ssm_parameter" "github_client_id" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  name        = "${local.ssm_prefix}/github/client-id"
  description = "Client ID of the GitHub OAuth app used to sign in to Grafana"
  type        = "SecureString"
  value       = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "github_client_secret" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  name        = "${local.ssm_prefix}/github/client-secret"
  description = "Client secret of the GitHub OAuth app used to sign in to Grafana"
  type        = "SecureString"
  value       = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}
