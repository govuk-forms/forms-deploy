locals {
  data_path         = "/var/lib/grafana"
  provisioning_path = "${local.data_path}/provisioning"

  # Grafana teams are exposed to the role mapping as "@<org>/<team>"
  github_role_attribute_path = join(" || ", concat(
    ["contains(groups[*], '@${var.github_admin_team}') && 'GrafanaAdmin'"],
    [for team in var.github_editor_teams : "contains(groups[*], '@${team}') && 'Editor'"]
  ))

  environment_variables = [
    { name = "GF_SERVER_ROOT_URL", value = "https://${local.host_name}/" },
    { name = "GF_SERVER_ENABLE_GZIP", value = "true" },
    { name = "GF_PATHS_DATA", value = local.data_path },
    { name = "GF_PATHS_PLUGINS", value = "${local.data_path}/plugins" },
    { name = "GF_PATHS_LOGS", value = "${local.data_path}/logs" },
    { name = "GF_PATHS_PROVISIONING", value = local.provisioning_path },
    { name = "GF_LOG_MODE", value = "console" },
    { name = "GF_DATABASE_TYPE", value = "postgres" },
    { name = "GF_DATABASE_HOST", value = "${aws_rds_cluster.grafana.endpoint}:${local.rds_port}" },
    { name = "GF_DATABASE_NAME", value = aws_rds_cluster.grafana.database_name },
    { name = "GF_DATABASE_USER", value = aws_rds_cluster.grafana.master_username },
    { name = "GF_DATABASE_SSL_MODE", value = "require" },
    { name = "GF_SECURITY_ADMIN_USER", value = "admin" },
    { name = "GF_SECURITY_COOKIE_SECURE", value = "true" },
    { name = "GF_USERS_ALLOW_SIGN_UP", value = "false" },
    { name = "GF_AUTH_GITHUB_ENABLED", value = "true" },
    { name = "GF_AUTH_GITHUB_AUTO_LOGIN", value = "true" },
    { name = "GF_AUTH_GITHUB_ALLOW_SIGN_UP", value = "true" },
    { name = "GF_AUTH_GITHUB_SCOPES", value = "user:email,read:org" },
    { name = "GF_AUTH_GITHUB_ALLOWED_ORGANIZATIONS", value = join(" ", var.github_allowed_organizations) },
    { name = "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_PATH", value = local.github_role_attribute_path },
    { name = "GF_AUTH_GITHUB_ROLE_ATTRIBUTE_STRICT", value = "true" },
    { name = "GF_AUTH_GITHUB_ALLOW_ASSIGN_GRAFANA_ADMIN", value = "true" },
    { name = "GF_UNIFIED_ALERTING_ENABLED", value = "false" },
    { name = "GF_ANALYTICS_REPORTING_ENABLED", value = "false" },
    { name = "GF_ANALYTICS_CHECK_FOR_UPDATES", value = "false" },
    { name = "GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES", value = "false" },
    { name = "GF_NEWS_NEWS_FEED_ENABLED", value = "false" },
    { name = "GF_AWS_ALLOWED_AUTH_PROVIDERS", value = "default" },
    { name = "GF_PLUGINS_PREINSTALL_SYNC", value = "grafana-amazonprometheus-datasource@3.2.0,grafana-x-ray-datasource@2.17.1" },
    { name = "GRAFANA_DATASOURCES_YAML", value = local.datasources_yaml },
  ]

  secrets = [
    { name = "GF_DATABASE_PASSWORD", valueFrom = aws_ssm_parameter.database_password.arn },
    { name = "GF_SECURITY_ADMIN_PASSWORD", valueFrom = aws_ssm_parameter.admin_password.arn },
    { name = "GF_SECURITY_SECRET_KEY", valueFrom = aws_ssm_parameter.secret_key.arn },
    { name = "GF_AUTH_GITHUB_CLIENT_ID", valueFrom = aws_ssm_parameter.github_client_id.arn },
    { name = "GF_AUTH_GITHUB_CLIENT_SECRET", valueFrom = aws_ssm_parameter.github_client_secret.arn },
  ]

  # Write the provisioning file, then hand over to the image's own entrypoint
  command = <<-EOT
    mkdir -p "$GF_PATHS_PROVISIONING/datasources" "$GF_PATHS_PROVISIONING/dashboards" "$GF_PATHS_PROVISIONING/plugins" "$GF_PATHS_PROVISIONING/alerting" "$GF_PATHS_PROVISIONING/notifiers" &&
    printf '%s' "$GRAFANA_DATASOURCES_YAML" > "$GF_PATHS_PROVISIONING/datasources/aws.yaml" &&
    exec /run.sh
  EOT

  container_definition = {
    name        = local.name
    image       = var.image
    essential   = true
    environment = local.environment_variables
    secrets     = local.secrets
    entryPoint  = ["/bin/sh", "-c"]
    command     = [local.command]
    # The image has no VOLUME for its data directory, so a bind mount there
    # would not be writable by the grafana user. Grafana writes plugins,
    # provisioning and cache files under /var/lib/grafana in the container
    # layer instead.
    readonlyRootFilesystem = false
    portMappings = [
      {
        hostPort      = local.container_port
        protocol      = "tcp"
        containerPort = local.container_port
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.grafana.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = local.name
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf http://localhost:${local.container_port}/api/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 5
      startPeriod = 180 # plugins install before Grafana listens, and the database may be resuming
    }
  }
}

resource "aws_ecs_task_definition" "grafana" {
  #checkov:skip=CKV_AWS_336:The image has no VOLUME for its data directory, so the root filesystem must be writable
  family                = local.name
  container_definitions = jsonencode([local.container_definition])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  network_mode = "awsvpc"

  enable_fault_injection = false
}

resource "aws_ecs_service" "grafana" {
  #checkov:skip=CKV_AWS_332:We don't want to target "LATEST" and get a surprise when a new version is released.
  #checkov:skip=CKV2_FORMS_AWS_2:We don't autoscale this service
  name                               = local.name
  cluster                            = var.ecs_cluster_arn
  task_definition                    = aws_ecs_task_definition.grafana.arn
  deployment_maximum_percent         = "200"
  deployment_minimum_healthy_percent = "100"
  desired_count                      = 1
  # Matches the container health check startPeriod, see above
  health_check_grace_period_seconds = 180

  launch_type      = "FARGATE"
  platform_version = "1.4.0"

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = local.name
    container_port   = local.container_port
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.grafana.id]
    assign_public_ip = false
  }

  lifecycle {
    prevent_destroy = true # ECS services cannot be destructively replaced without downtime. This helps to avoid accidentally doing so.
  }
}
