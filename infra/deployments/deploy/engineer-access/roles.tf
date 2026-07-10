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
  pentesters = []
  pentester_cidrs = [
    "88.98.40.224/27",
    "172.167.216.147/32",
    "3.10.36.101/32",
    "35.178.26.242/32",
    "18.168.92.160/32",
    "18.134.34.111/32",
    "13.41.39.172/32",
    "20.123.237.233/32",
    "88.208.100.190/32"
  ]
}
