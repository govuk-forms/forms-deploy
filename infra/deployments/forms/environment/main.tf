module "environment" {
  source      = "../../../modules/environment"
  env_name    = var.environment_name
  env_type    = var.environment_type
  root_domain = var.root_domain

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  send_logs_to_cyber            = var.send_logs_to_cyber
  kinesis_subscription_role_arn = data.terraform_remote_state.account.outputs.kinesis_subscription_role_arn

  ips_to_block            = var.environmental_settings.ips_to_block
  rate_limit_bypass_cidrs = var.environmental_settings.rate_limit_bypass_cidrs
  enable_alert_actions    = var.environmental_settings.enable_alert_actions

  enable_shield_advanced_healthchecks = var.environmental_settings.enable_shield_advanced_healthchecks
  scheduled_smoke_tests_settings      = var.scheduled_smoke_tests_settings

  serve_assets_from_s3 = var.environmental_settings.serve_assets_from_s3
}
