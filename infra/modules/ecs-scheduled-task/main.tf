data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  log_stream_prefix = coalesce(var.log_stream_prefix, var.task_family)

  main_container_definition = merge(
    var.base_task_container_definition,
    {
      name    = var.container_name
      command = var.command
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = var.application_log_group_name,
          awslogs-region        = data.aws_region.current.region,
          awslogs-stream-prefix = local.log_stream_prefix
        }
      },
      # Override dependsOn from the app task definition; scheduled tasks have no otel sidecar.
      dependsOn = [],
      # Strip OTEL env vars so tracing is not enabled without the collector sidecar.
      environment = [
        for env in var.base_task_container_definition.environment :
        env
        if !startswith(env.name, "OTEL_") && !endswith(env.name, "_OTEL")
      ]
    }
  )

  schedule_rule_description = coalesce(
    var.schedule_rule_description,
    "Trigger the ${var.task_family} ECS task on a schedule"
  )
}

resource "aws_ecs_task_definition" "this" {
  family = var.task_family

  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  requires_compatibilities = var.requires_compatibilities
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = "awsvpc"
  track_latest             = true

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([local.main_container_definition])
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = var.schedule_rule_name
  description         = local.schedule_rule_description
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "this" {
  arn      = var.ecs_cluster_arn
  rule     = aws_cloudwatch_event_rule.this.name
  role_arn = var.scheduler_role_arn

  ecs_target {
    # EventBridge must target task family ARN without revision to always run latest.
    task_definition_arn = "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task-definition/${aws_ecs_task_definition.this.family}"
    launch_type         = "FARGATE"
    platform_version    = var.platform_version

    network_configuration {
      assign_public_ip = false
      security_groups  = var.network_security_groups
      subnets          = var.network_subnets
    }
  }

  dead_letter_config {
    arn = var.eventbridge_dead_letter_queue_arn
  }
}
