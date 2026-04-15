module "users" {
  source = "../../../modules/users"
}

module "engineer_access" {
  source                    = "../../../modules/engineer-access"
  env_name                  = var.account_name
  environment_type          = var.environment_type
  admins                    = module.users.with_role["${var.environment_type}_admin"]
  support                   = module.users.with_role["${var.environment_type}_support"]
  readonly                  = module.users.with_role["${var.environment_type}_readonly"]
  pentesters                = var.pentester_email_addresses
  pentester_cidrs           = var.pentester_cidr_ranges
  vpn                       = var.require_vpn_to_access
  codestar_connection_arn   = var.codestar_connection_arn
  allow_rds_data_api_access = true
  allow_ecs_task_usage      = true
  state_file_bucket_name    = var.bucket
}
