output "auth0_user_name_parameter_name" {
  value = aws_ssm_parameter.auth0_username.name
}

output "auth0_user_password_parameter_name" {
  value = aws_ssm_parameter.auth0_user_password.name
}

output "notify_api_key_parameter_name" {
  value = aws_ssm_parameter.notify_api_key.name
}

output "one_login_user_email_parameter_name" {
  value = aws_ssm_parameter.one_login_user_email.name
}

output "one_login_user_password_parameter_name" {
  value = aws_ssm_parameter.one_login_user_password.name
}

output "one_login_user_otp_secret_key_parameter_name" {
  value = aws_ssm_parameter.one_login_user_otp_secret_key.name
}
