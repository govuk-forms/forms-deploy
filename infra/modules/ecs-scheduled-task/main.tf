data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_ecs_task_definition" "this" {
  family = var.task_name

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

  container_definitions = jsonencode([merge(
    var.base_task_container_definition,
    {
      name    = "main"
      command = var.command
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = var.application_log_group_name,
          awslogs-region        = data.aws_region.current.name,
          awslogs-stream-prefix = var.task_name
        }
      }
    }
  )])
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = var.task_name
  description         = "Trigger the ${var.task_name} ECS task on a schedule"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "this" {
  arn      = var.ecs_cluster_arn
  rule     = aws_cloudwatch_event_rule.this.name
  role_arn = var.scheduler_role_arn

  ecs_target {
    # EventBridge must target task family ARN without revision to always run latest.
    task_definition_arn = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task-definition/${aws_ecs_task_definition.this.family}"
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
