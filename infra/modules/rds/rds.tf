locals {
  rds_port = 5432
}

data "aws_ssm_parameter" "database_password" {
  name       = "/${var.identifier}/database/root-password"
  depends_on = [aws_ssm_parameter.database_password_for_root_user]
}

resource "aws_rds_cluster_parameter_group" "aurora_postgres_v13" {
  name_prefix = "forms-${var.identifier}-pg13"
  family      = "aurora-postgresql13"
  description = "RDS cluster parameter group for Aurora Serverless for PostgreSQL 13"
}

resource "aws_rds_cluster_parameter_group" "aurora_postgres_v16" {
  name_prefix = "forms-${var.identifier}-pg16"
  family      = "aurora-postgresql16"
  description = "RDS cluster parameter group for Aurora Serverless for PostgreSQL 16"
}

locals {
  # This must be a multiple of 31. 465 is the minimum for advanced database insights (15 months).
  performance_insights_retention_period = var.enable_advanced_database_insights ? 465 : null
}

resource "aws_rds_cluster" "cluster_aurora_v2" {
  #checkov:skip=CKV2_AWS_8:AWS RDS inbuilt backup process is sufficient
  #checkov:skip=CKV2_AWS_27:Query logging is not required at this time
  #checkov:skip=CKV_AWS_128:IAM auth to be considered: https://trello.com/c/nY2TcBXb/418-consider-rds-iam-auth
  #checkov:skip=CKV_AWS_162:Duplicate of CKV_AWS_128
  #checkov:skip=CKV_AWS_324:Log capture is not required at this time
  #checkov:skip=CKV_AWS_327:Database is already encrypted with the default key, and we feel this is sufficient

  cluster_identifier = "aurora-v2-cluster-${var.identifier}"

  availability_zones = var.availability_zones

  master_username = "root"
  master_password = data.aws_ssm_parameter.database_password.value
  port            = local.rds_port

  engine         = "aurora-postgresql"
  engine_mode    = "provisioned"
  engine_version = "16.6"

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.id

  enable_http_endpoint = true

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_postgres_v16.id

  apply_immediately            = var.apply_immediately
  preferred_maintenance_window = var.rds_maintenance_window

  skip_final_snapshot       = false
  final_snapshot_identifier = "forms-${var.identifier}-final-snapshot"
  copy_tags_to_snapshot     = true
  storage_encrypted         = true
  backup_retention_period   = var.backup_retention_period
  deletion_protection       = true

  database_insights_mode = var.enable_advanced_database_insights ? "advanced" : null

  # performance insights with 15 month retention is required for advanced database insights
  # https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/USER_DatabaseInsights.TurningOnAdvanced.html
  performance_insights_enabled          = var.enable_advanced_database_insights
  performance_insights_retention_period = local.performance_insights_retention_period

  serverlessv2_scaling_configuration {
    max_capacity = var.max_capacity
    min_capacity = var.min_capacity
  }

  lifecycle {
    # Do not remove "restore_to_point_in_time" from this block unless you are trying
    # to create a new database from a point in time.
    #
    # We specified version 11.18 when we created the database clusters
    # but since then AWS have provided automatic minor version upgrades.
    #
    # We don't wish for Terraform to attempt to downgrade the engine version,
    # or to have to update our config every time there's a new minor version.
    # Instead, we ignore any changes to the engine version, and allow AWS to
    # be the arbiter of the exact version.
    #
    # When we want to perform major version upgrades, we can remove this lifecycle
    # "engine_version" configuration, and replace it once the upgrade is complete.
    ignore_changes = [
      snapshot_identifier,
      engine_version,
      db_cluster_parameter_group_name,
      restore_to_point_in_time
    ]
  }

  depends_on = [
    aws_rds_cluster_parameter_group.aurora_postgres_v16
  ]
}

resource "aws_rds_cluster_instance" "member" {
  #checkov:skip=CKV_AWS_118:We don't currently have enhanced monitoring
  #checkov:skip=CKV_AWS_354:We can use the default kms key for encryption

  cluster_identifier = aws_rds_cluster.cluster_aurora_v2.id
  engine             = "aurora-postgresql"
  instance_class     = "db.serverless"
  identifier         = var.database_identifier

  force_destroy = false

  performance_insights_enabled          = var.enable_advanced_database_insights
  performance_insights_retention_period = local.performance_insights_retention_period

  auto_minor_version_upgrade = true
}
