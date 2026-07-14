variable "apply_immediately" {
  type        = bool
  description = "Whether to apply change to the database immediately, or in the next maintenance window."
  default     = false
}

module "rds" {
  # this is the rds cluster for the forms-admin database
  source     = "../../../modules/rds"
  env_name   = var.environment_name
  identifier = var.environment_name

  vpc_id              = data.terraform_remote_state.forms_environment.outputs.vpc_id
  subnet_ids          = data.terraform_remote_state.forms_environment.outputs.private_subnet_ids
  ingress_cidr_blocks = [data.terraform_remote_state.forms_environment.outputs.vpc_cidr_block]

  apply_immediately        = var.apply_immediately
  rds_maintenance_window   = var.environmental_settings.rds_maintenance_window
  min_capacity             = var.environmental_settings.rds_minimum_capacity_acus
  max_capacity             = var.environmental_settings.rds_maxium_capacity_acus
  auto_pause               = var.environmental_settings.pause_databases_on_inactivity
  seconds_until_auto_pause = var.environmental_settings.pause_databases_after_inactivity_seconds
  backup_retention_period  = var.environmental_settings.database_backup_retention_period_days
  force_ssl_connections    = var.environmental_settings.rds_force_ssl_connections

  enable_advanced_database_insights = var.environmental_settings.enable_advanced_database_insights

  apps_list = {
    forms-admin = { username = "forms-admin-app" }
  }
  database_identifier = "primary"
}

module "forms_runner_rds" {
  # this is the rds cluster for the forms-runner database
  source     = "../../../modules/rds"
  env_name   = var.environment_name
  identifier = "forms-runner-${var.environment_name}"

  vpc_id              = data.terraform_remote_state.forms_environment.outputs.vpc_id
  subnet_ids          = data.terraform_remote_state.forms_environment.outputs.private_subnet_ids
  ingress_cidr_blocks = [data.terraform_remote_state.forms_environment.outputs.vpc_cidr_block]

  apply_immediately        = var.apply_immediately
  rds_maintenance_window   = var.environmental_settings.rds_maintenance_window
  min_capacity             = var.environmental_settings.rds_minimum_capacity_acus
  max_capacity             = var.environmental_settings.rds_maxium_capacity_acus
  auto_pause               = var.environmental_settings.pause_databases_on_inactivity
  seconds_until_auto_pause = var.environmental_settings.pause_databases_after_inactivity_seconds
  backup_retention_period  = var.environmental_settings.database_backup_retention_period_days
  force_ssl_connections    = var.environmental_settings.rds_force_ssl_connections

  enable_advanced_database_insights = var.environmental_settings.enable_advanced_database_insights

  apps_list = {
    forms-runner       = { username = "forms-runner-app" }
    forms-runner-queue = { username = "forms-runner-app-queue" }
  }
  database_identifier = "forms-runner-${var.environment_name}-primary"
}

# Create an IAM role to allow RDS enhanced monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name        = "RDSEnhancedMonitoring"
  description = "Used to enable enhanced monitoring in RDS"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
