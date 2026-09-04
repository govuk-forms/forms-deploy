module "grafana" {
  count  = var.grafana_settings.enabled ? 1 : 0
  source = "../../../modules/grafana"

  # The module passes the provider on to the certificate module, which
  # requires it to be passed explicitly here.
  providers = {
    aws = aws
  }

  root_domain = var.root_domain

  vpc_id                      = data.terraform_remote_state.forms_environment.outputs.vpc_id
  vpc_cidr_block              = data.terraform_remote_state.forms_environment.outputs.vpc_cidr_block
  private_subnet_ids          = data.terraform_remote_state.forms_environment.outputs.private_subnet_ids
  public_subnet_ids           = data.terraform_remote_state.forms_environment.outputs.public_subnet_ids
  ecs_cluster_arn             = data.terraform_remote_state.forms_environment.outputs.ecs_cluster_arn
  alb_access_logs_bucket_name = data.terraform_remote_state.forms_environment.outputs.alb_logs_bucket_name

  kinesis_subscription_role_arn = data.terraform_remote_state.account.outputs.kinesis_subscription_role_arn

  cpu                          = var.grafana_settings.cpu
  memory                       = var.grafana_settings.memory
  github_allowed_organizations = var.grafana_settings.github_allowed_organizations
  github_admin_team            = var.grafana_settings.github_admin_team
  github_editor_teams          = var.grafana_settings.github_editor_teams
  seconds_until_auto_pause     = var.grafana_settings.seconds_until_auto_pause
  rds_maintenance_window       = var.environmental_settings.rds_maintenance_window
}
