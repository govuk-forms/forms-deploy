resource "aws_ssm_parameter" "auth0_username" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  name  = "/${var.environment_name}/automated-tests/e2e/auth0/email-username"
  type  = "SecureString"
  value = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "auth0_user_password" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  name  = "/${var.environment_name}/automated-tests/e2e/auth0/auth0-user-password"
  type  = "SecureString"
  value = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "notify_api_key" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  name  = "/${var.environment_name}/automated-tests/e2e/notify/api-key"
  type  = "SecureString"
  value = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "one_login_user_email" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  name  = "/${var.environment_name}/automated-tests/e2e/one-login/user-email"
  type  = "SecureString"
  value = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "one_login_user_password" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  name  = "/${var.environment_name}/automated-tests/e2e/one-login/user-password"
  type  = "SecureString"
  value = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "one_login_user_otp_secret_key" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  name  = "/${var.environment_name}/automated-tests/e2e/one-login/user-otp-secret-key"
  type  = "SecureString"
  value = "dummy-value"

  lifecycle {
    ignore_changes = [value]
  }
}
