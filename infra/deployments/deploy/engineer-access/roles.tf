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
  pentesters = [
    "matus.mihok2@digital.cabinet-office.gov.uk",
    "caleb.herbert1@digital.cabinet-office.gov.uk",
    "cameron.steel@digital.cabinet-office.gov.uk"
  ]
  pentester_cidrs = [
    "172.167.139.53/32",
    "172.166.224.184/32",
    "172.167.51.76/32",
    "4.234.97.14/32",
    "20.0.43.178/32",
    "4.234.140.58/32",
    "51.142.199.225/32",
    "20.162.198.121/32"
  ]
}
