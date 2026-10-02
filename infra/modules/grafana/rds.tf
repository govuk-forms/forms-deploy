locals {
  rds_port = 5432
}

resource "aws_db_subnet_group" "grafana" {
  name        = local.name
  description = "${local.name} subnet group"
  subnet_ids  = var.private_subnet_ids
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds"
  description = "Security group for the Grafana database"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name}-rds"
  }
}

resource "aws_rds_cluster" "grafana" {
  #checkov:skip=CKV2_AWS_8:AWS RDS inbuilt backup process is sufficient
  #checkov:skip=CKV2_AWS_27:Query logging is not required at this time
  #checkov:skip=CKV_AWS_128:IAM auth to be considered: https://trello.com/c/nY2TcBXb/418-consider-rds-iam-auth
  #checkov:skip=CKV_AWS_162:Duplicate of CKV_AWS_128
  #checkov:skip=CKV_AWS_324:Log capture is not required at this time
  #checkov:skip=CKV_AWS_327:Database is already encrypted with the default key, and we feel this is sufficient

  cluster_identifier = local.name

  database_name   = "grafana"
  master_username = "grafana"
  master_password = random_password.database.result
  port            = local.rds_port

  engine      = "aurora-postgresql"
  engine_mode = "provisioned"
  # Only used when the cluster is created; AWS then manages minor upgrades
  # (see ignore_changes below). Deprecated minor versions cannot be used to
  # create a cluster, so bump this to a current one if creation fails.
  engine_version = "18.4"

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.grafana.name

  preferred_maintenance_window = var.rds_maintenance_window

  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name}-final-snapshot"
  copy_tags_to_snapshot     = true
  storage_encrypted         = true
  backup_retention_period   = 7
  deletion_protection       = true

  # Grafana keeps a connection pool open and polls its database, so the
  # cluster will only pause while the Grafana service is stopped. It costs
  # nothing to allow it to pause when that happens.
  serverlessv2_scaling_configuration {
    min_capacity             = 0
    max_capacity             = 1
    seconds_until_auto_pause = var.seconds_until_auto_pause
  }

  lifecycle {
    # AWS applies minor version upgrades automatically; don't fight it.
    # restore_to_point_in_time must remain ignored, see CKV2_FORMS_AWS_3.
    ignore_changes = [
      engine_version,
      restore_to_point_in_time
    ]
  }
}

resource "aws_rds_cluster_instance" "grafana" {
  #checkov:skip=CKV_AWS_118:We don't currently have enhanced monitoring
  #checkov:skip=CKV_AWS_354:We can use the default kms key for encryption
  #checkov:skip=CKV_AWS_353:Performance insights are not required for this database

  cluster_identifier = aws_rds_cluster.grafana.id
  engine             = aws_rds_cluster.grafana.engine
  instance_class     = "db.serverless"
  identifier         = local.name

  auto_minor_version_upgrade = true
}
