module "users" {
  source = "../../../modules/users"
}

module "engineer_access" {
  source                    = "../../../modules/engineer-access"
  admins                    = module.users.with_role["deploy_admin"]
  support                   = module.users.with_role["deploy_support"]
  readonly                  = module.users.with_role["deploy_readonly"]
  env_name                  = "deploy"
  environment_type          = "deploy"
  codestar_connection_arn   = var.codestar_connection_arn
  allow_ecs_task_usage      = false
  allow_rds_data_api_access = false
  state_file_bucket_name    = "gds-forms-deploy-tfstate"

  # Pentesters may not have GDS domains so our pattern using the 'users' module
  # doesn't necessarily work.
  pentesters      = []
  pentester_cidrs = []
}
