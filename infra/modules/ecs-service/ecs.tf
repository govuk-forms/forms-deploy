data "aws_ecs_task_definition" "active_task" {
  count           = var.image == null ? 1 : 0
  task_definition = local.task_definition_family
}

data "aws_ecs_container_definition" "active_container" {
  count           = var.image == null ? 1 : 0
  task_definition = data.aws_ecs_task_definition.active_task[0].id
  container_name  = var.application
}

locals {
  log_group_name         = "/aws/ecs/${var.application}-${var.env_name}"
  adot_log_group_name    = "/aws/ecs/${var.application}-${var.env_name}/adot-collector"
  task_definition_family = "${var.env_name}_${var.application}"

  image = var.image == null ? data.aws_ecs_container_definition.active_container[0].image : var.image

  # When OpenTelemetry is enabled, calculate total resources needed
  otel_total_cpu    = var.cpu + var.adot_sidecar_cpu
  otel_total_memory = var.memory + var.adot_sidecar_memory

  # Round up CPU to next valid Fargate tier (256, 512, 1024, 2048, 4096, 8192, 16384)
  # See: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-tasks-services.html#fargate-tasks-size
  otel_fargate_cpu = (
    local.otel_total_cpu <= 256 ? 256 :
    local.otel_total_cpu <= 512 ? 512 :
    local.otel_total_cpu <= 1024 ? 1024 :
    local.otel_total_cpu <= 2048 ? 2048 :
    local.otel_total_cpu <= 4096 ? 4096 :
    local.otel_total_cpu <= 8192 ? 8192 : 16384
  )

  # Minimum memory (in MB) required for each Fargate CPU tier
  # 256 CPU -> 512 MB, 512 CPU -> 1024 MB, 1024 CPU -> 2048 MB,
  # 2048 CPU -> 4096 MB, 4096 CPU -> 8192 MB, 8192 CPU -> 16384 MB, 16384 CPU -> 32768 MB
  otel_min_memory_for_cpu = (
    local.otel_fargate_cpu <= 256 ? 512 :
    local.otel_fargate_cpu <= 512 ? 1024 :
    local.otel_fargate_cpu <= 1024 ? 2048 :
    local.otel_fargate_cpu <= 2048 ? 4096 :
    local.otel_fargate_cpu <= 4096 ? 8192 :
    local.otel_fargate_cpu <= 8192 ? 16384 : 32768
  )

  # Round up memory to next valid Fargate tier, respecting minimum for chosen CPU
  # Memory tiers: 512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192, then 1GB increments
  # up to 30GB for 4vCPU, 4GB increments up to 60GB for 8vCPU, 8GB increments up to 120GB for 16vCPU
  otel_fargate_memory = max(
    local.otel_min_memory_for_cpu,
    local.otel_total_memory <= 512 ? 512 :
    local.otel_total_memory <= 1024 ? 1024 :
    local.otel_total_memory <= 2048 ? 2048 :
    local.otel_total_memory <= 4096 ? 4096 :
    local.otel_total_memory <= 8192 ? 8192 :
    local.otel_total_memory <= 16384 ? 16384 :
    local.otel_total_memory <= 32768 ? 32768 : 65536
  )

  task_container_definition = {
    name = var.application,
    environment = var.enable_opentelemetry ? concat(var.environment_variables, [
      {
        name  = "ENABLE_OTEL"
        value = "true"
      },
      {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "http://localhost:4318" # ADOT sidecar listens on this endpoint
      },
      {
        name  = "OTEL_PROPAGATORS"
        value = "xray"
      },
      {
        name  = "OTEL_SERVICE_NAME"
        value = var.application
      },
      {
        name  = "OTEL_TRACES_SAMPLER"
        value = "parentbased_traceidratio"
      },
      {
        name  = "OTEL_TRACES_SAMPLER_ARG"
        value = var.opentelemetry_head_sampler_ratio
      }
    ]) : var.environment_variables,
    mountPoints            = [],
    secrets                = var.secrets,
    image                  = local.image
    essential              = true,
    readonlyRootFilesystem = var.readonly_root_filesystem
    portMappings = [
      {
        hostPort      = var.container_port,
        protocol      = "tcp",
        containerPort = var.container_port,
      }
    ],
    systemControls = [],
    volumesFrom    = [],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = local.log_group_name,
        awslogs-region        = "eu-west-2",
        awslogs-stream-prefix = local.log_group_name
      }
    },
    healthCheck = var.healthcheck,
    dependsOn = var.enable_opentelemetry ? [
      {
        containerName = "aws-otel-collector",
        condition     = "START"
      }
    ] : []
  }

  # ADOT collector sidecar container (only evaluated when OpenTelemetry is enabled)
  adot_container_definition = var.enable_opentelemetry ? {
    name                   = "aws-otel-collector",
    image                  = var.adot_image,
    essential              = false,
    readonlyRootFilesystem = true,
    cpu                    = var.adot_sidecar_cpu,
    memory                 = var.adot_sidecar_memory,
    secrets = [
      {
        name      = "AOT_CONFIG_CONTENT"
        valueFrom = aws_ssm_parameter.adot_collector_config[0].arn
      }
    ],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = local.adot_log_group_name,
        awslogs-region        = "eu-west-2",
        awslogs-stream-prefix = "adot"
      }
    },
    healthCheck = {
      command = [
        "CMD",
        "/healthcheck"
      ],
      interval    = 30,
      timeout     = 5,
      retries     = 5,
      startPeriod = 10
    },
  } : null

  # Conditional container array composition
  container_definitions = var.enable_opentelemetry ? jsonencode([
    local.task_container_definition,
    local.adot_container_definition
    ]) : jsonencode([
    local.task_container_definition
  ])

  # Extract the values needed for the ECS service network configuration
  # to local variable so we can ensure the same configuration is used
  # for any pre-deploy tasks
  ecs_service_network_configuration = {
    subnets        = var.private_subnet_ids
    securityGroups = [aws_security_group.baseline.id]
    assignPublicIp = false
  }
}
resource "aws_ecs_task_definition" "task" {
  family                = local.task_definition_family
  container_definitions = local.container_definitions

  // As this terraform module doesn't deal with updating app code, we see drift every time it's applied because the image is changed elsewhere.
  // Enable tracking of the latest ACTIVE task definition revision rather than the one in terraform state, so that changes to the image / task revision outside of terraform are picked up and not considered drift.
  // This is only necessary when terraform itself is not the source of truth for the task definition image.
  // See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition#track_latest-1
  track_latest = true

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  execution_role_arn = aws_iam_role.ecs_task_exec_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  requires_compatibilities = ["FARGATE"]
  cpu                      = var.enable_opentelemetry ? local.otel_fargate_cpu : var.cpu
  memory                   = var.enable_opentelemetry ? local.otel_fargate_memory : var.memory

  network_mode = "awsvpc"

  enable_fault_injection = false
}

resource "aws_ecs_service" "app_service" {
  #checkov:skip=CKV_AWS_332:We don't want to target "LATEST" and get a surprise when a new version is released.
  name                               = var.application
  cluster                            = var.ecs_cluster_arn
  task_definition                    = aws_ecs_task_definition.task.arn
  deployment_maximum_percent         = "200"
  deployment_minimum_healthy_percent = "100"

  launch_type      = "FARGATE"
  platform_version = "1.4.0"

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = var.application
    container_port   = var.container_port
  }

  dynamic "load_balancer" {
    for_each = var.internal_sub_domain != null ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.internal_tg[0].arn
      container_name   = var.application
      container_port   = var.container_port
    }
  }

  lifecycle {
    prevent_destroy = true # ECS services cannot be destructively replaced without downtime. This helps to avoid accidentally doing so.
    ignore_changes  = [desired_count]
  }

  network_configuration {
    subnets          = local.ecs_service_network_configuration.subnets
    security_groups  = local.ecs_service_network_configuration.securityGroups
    assign_public_ip = local.ecs_service_network_configuration.assignPublicIp
  }

  depends_on = [
    null_resource.pre_deploy_script
  ]
}
