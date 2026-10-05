locals {
  queue_worker_name           = "${module.ecs_service.task_container_definition.name}-queue-worker"
  queue_worker_log_group_name = "/aws/ecs/${local.queue_worker_name}-${var.env_name}"

  # OTTL expressions for the ADOT filter/drop_spans processor.
  # These drop the high-volume SolidQueue polling spans that create noise in X-Ray
  # without obscuring the job work we actually care about (S3, SES, submissions).
  #
  # Confirmed against live traces:
  # - "forms-runner-queue": bare DB poll spans (always single-span root, no children)
  # - "ActiveRecord.transaction": SolidQueue internal bookkeeping transactions
  #   (root spans whose only children are SolidQueue::* subsegments — no real job work)
  # - "SolidQueue::.*": always subsegments of ActiveRecord.transaction, dropped with parent
  queue_worker_drop_span_expressions = [
    "IsMatch(name, \"SolidQueue::.*\")",
    "name == \"ActiveRecord.transaction\"",
    "IsMatch(name, \"(BEGIN|COMMIT|SELECT|INSERT|UPDATE|DELETE|EXECUTE) forms-runner-queue\")",
  ]

  # Round up CPU/memory to next valid Fargate tier when OTEL is enabled,
  # mirroring the logic in the ecs-service module.
  queue_worker_total_cpu    = var.cpu + module.ecs_service.adot_sidecar_cpu
  queue_worker_total_memory = var.memory + module.ecs_service.adot_sidecar_memory

  queue_worker_fargate_cpu = (
    local.queue_worker_total_cpu <= 256 ? 256 :
    local.queue_worker_total_cpu <= 512 ? 512 :
    local.queue_worker_total_cpu <= 1024 ? 1024 :
    local.queue_worker_total_cpu <= 2048 ? 2048 :
    local.queue_worker_total_cpu <= 4096 ? 4096 :
    local.queue_worker_total_cpu <= 8192 ? 8192 : 16384
  )

  queue_worker_min_memory_for_cpu = (
    local.queue_worker_fargate_cpu <= 256 ? 512 :
    local.queue_worker_fargate_cpu <= 512 ? 1024 :
    local.queue_worker_fargate_cpu <= 1024 ? 2048 :
    local.queue_worker_fargate_cpu <= 2048 ? 4096 :
    local.queue_worker_fargate_cpu <= 4096 ? 8192 :
    local.queue_worker_fargate_cpu <= 8192 ? 16384 : 32768
  )

  queue_worker_fargate_memory = max(
    local.queue_worker_min_memory_for_cpu,
    local.queue_worker_total_memory <= 512 ? 512 :
    local.queue_worker_total_memory <= 1024 ? 1024 :
    local.queue_worker_total_memory <= 2048 ? 2048 :
    local.queue_worker_total_memory <= 4096 ? 4096 :
    local.queue_worker_total_memory <= 8192 ? 8192 :
    local.queue_worker_total_memory <= 16384 ? 16384 :
    local.queue_worker_total_memory <= 32768 ? 32768 : 65536
  )

  # Take the exported task container definition and override some parts of it.
  # Note: the ENV variables aren't overridden because it's not possible to cherry pick them.
  # This means DISABLE_SOLID_QUEUE is always set to true, but that instruction is overridden
  # by the command `bin/jobs` which starts the SolidQueue worker but not the Rails server.
  queue_worker_container_definition = merge(
    module.ecs_service.task_container_definition,
    {
      name = local.queue_worker_name,

      command = ["bin/jobs"]
      image   = module.ecs_service.task_container_definition.image,

      healthCheck = {
        command     = ["CMD-SHELL", "test -f tmp/solidqueue_healthcheck || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = local.queue_worker_log_group_name,
          awslogs-region        = "eu-west-2",
          awslogs-stream-prefix = local.queue_worker_log_group_name
        }
      }

      # When OTEL is enabled, the ADOT sidecar is provisioned alongside this container;
      # restore the dependsOn so the app waits for the collector to start.
      dependsOn = var.enable_opentelemetry ? [
        {
          containerName = "aws-otel-collector",
          condition     = "START"
        }
      ] : [],

      # Pass env vars through, overriding OTEL_SERVICE_NAME so the queue worker appears
      # as a distinct service in X-Ray rather than merged with the main forms-runner app.
      # OTEL_TRACES_SAMPLER_ARG is set to 1.0 to capture all traces — the queue worker
      # emits low volumes of real job work, so full sampling is appropriate here.
      environment = [
        for env in module.ecs_service.task_container_definition.environment :
        (env.name == "OTEL_SERVICE_NAME"
          ? merge(env, { value = "forms-runner-queue-worker" })
          : env.name == "OTEL_TRACES_SAMPLER_ARG"
          ? merge(env, { value = "1" })
        : env)
      ]

      secrets = [
        {
          name      = "SETTINGS__GOVUK_NOTIFY__API_KEY",
          valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/notify-api-key"
        },
        {
          name      = "SETTINGS__SENTRY__DSN",
          valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-queue-worker-${var.env_name}/sentry/dsn"
        },
        {
          name      = "SECRET_KEY_BASE",
          valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/secret-key-base"
        },
        {
          name      = "DATABASE_URL",
          valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/database/url"
        },
        {
          name      = "QUEUE_DATABASE_URL",
          valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-queue-${var.env_name}/database/url"
        }
      ]
    }
  )

  # ADOT sidecar for the queue worker — same image as the main app's sidecar but with
  # a queue-worker-specific config that includes the polling-noise filter.
  queue_worker_adot_container_definition = var.enable_opentelemetry ? {
    name                   = "aws-otel-collector",
    image                  = module.ecs_service.adot_image,
    essential              = false,
    readonlyRootFilesystem = true,
    cpu                    = module.ecs_service.adot_sidecar_cpu,
    memory                 = module.ecs_service.adot_sidecar_memory,
    # A hash of the collector config is included as a Docker label so that any change to
    # the config template produces a different container_definitions JSON, which forces a
    # new task definition revision and triggers an ECS redeployment automatically.
    dockerLabels = {
      "adot-config-hash" = sha256(aws_ssm_parameter.queue_worker_adot_collector_config[0].value)
    },
    secrets = [
      {
        name      = "AOT_CONFIG_CONTENT"
        valueFrom = aws_ssm_parameter.queue_worker_adot_collector_config[0].arn
      }
    ],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = "${local.queue_worker_log_group_name}/adot-collector",
        awslogs-region        = "eu-west-2",
        awslogs-stream-prefix = "adot"
      }
    },
    healthCheck = {
      command     = ["CMD", "/healthcheck"],
      interval    = 30,
      timeout     = 5,
      retries     = 5,
      startPeriod = 10
    },
  } : null
}

resource "aws_ecs_task_definition" "queue_worker" {
  family = "${var.env_name}-${local.queue_worker_name}"
  container_definitions = var.enable_opentelemetry ? jsonencode([
    local.queue_worker_container_definition,
    local.queue_worker_adot_container_definition,
  ]) : jsonencode([local.queue_worker_container_definition])
  execution_role_arn       = aws_iam_role.ecs_task_exec_role.arn
  task_role_arn            = module.ecs_service.task_definition.task_role_arn
  requires_compatibilities = module.ecs_service.task_definition.requires_compatibilities
  cpu                      = var.enable_opentelemetry ? local.queue_worker_fargate_cpu : var.cpu
  memory                   = var.enable_opentelemetry ? local.queue_worker_fargate_memory : var.memory
  network_mode             = "awsvpc"

  // As this terraform module doesn't deal with updating app code, we see drift every time it's applied because the image is changed elsewhere.
  // Enable tracking of the latest ACTIVE task definition revision rather than the one in terraform state, so that changes to the image / task revision outside of terraform are picked up and not considered drift.
  // This is only necessary when terraform itself is not the source of truth for the task definition image.
  // See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition#track_latest-1
  track_latest = true

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

resource "aws_ecs_service" "queue_worker" {
  #checkov:skip=CKV_AWS_332:We don't want to target "LATEST" and get a surprise when a new version is released.
  #checkov:skip=CKV2_FORMS_AWS_2:The queue worker currently doesn't autoscale, revisit this decision by 23/06/2025
  name          = local.queue_worker_name
  cluster       = var.ecs_cluster_arn
  desired_count = var.queue_worker_capacity

  task_definition                    = aws_ecs_task_definition.queue_worker.arn
  deployment_maximum_percent         = "200"
  deployment_minimum_healthy_percent = "100"

  launch_type      = "FARGATE"
  platform_version = "1.4.0"

  lifecycle {
    prevent_destroy = true # ECS services cannot be destructively replaced without downtime. This helps to avoid accidentally doing so.
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.queue_worker.id]
    assign_public_ip = false
  }
}

resource "aws_security_group" "queue_worker" {
  name        = local.queue_worker_name
  description = "Restrict all ingress, allow egress to VPC, RDS, and internet"
  vpc_id      = var.vpc_id
  egress {
    description = "Permit outbound to VPC CIDR on 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "Permit outbound to the RDS postgres port 5432"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "Permit outbound 443 to the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Permit outbound to internal ALB on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }
}

resource "aws_iam_role" "ecs_task_exec_role" {
  name               = "${var.env_name}-${local.queue_worker_name}-ecs-task-execution"
  description        = "Used by ECS to create ${local.queue_worker_name} task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_exec_role_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_exec_role_assume_role" {
  statement {
    sid     = "AllowECS"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_standard_policy" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_task_exec_additional_policy" {
  name   = "${var.env_name}-${local.queue_worker_name}-ecs-task-execution-additional"
  policy = data.aws_iam_policy_document.queue_worker_ecs_task_exec_additional_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_additional_policy" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = aws_iam_policy.ecs_task_exec_additional_policy.arn
}

data "aws_iam_policy_document" "queue_worker_ecs_task_exec_additional_policy" {
  statement {
    actions = [
      "ssm:DescribeParameters"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "ssm:GetParameters"
    ]
    resources = concat(
      [
        for parameter in local.queue_worker_container_definition.secrets : parameter.valueFrom
        if startswith(parameter.valueFrom, "arn:aws:ssm:")
      ],
      var.enable_opentelemetry ? [aws_ssm_parameter.queue_worker_adot_collector_config[0].arn] : [],
    )
    effect = "Allow"
  }
}

resource "aws_ssm_parameter" "queue_worker_sentry_dsn" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  name  = "/${local.queue_worker_name}-${var.env_name}/sentry/dsn"
  type  = "SecureString"
  value = "dummy_value"

  description = "Sentry DSN value for ${local.queue_worker_name} in the ${var.env_name} environment"

  lifecycle {
    ignore_changes  = [value]
    prevent_destroy = true
  }
}

data "aws_region" "current" {}

resource "aws_ssm_parameter" "queue_worker_adot_collector_config" {
  #checkov:skip=CKV2_AWS_34:Not a secret; the config template is committed to this public repository
  #checkov:skip=CKV2_FORMS_AWS_7:Value is not a secret set outside Terraform; it must track changes to the config template

  count = var.enable_opentelemetry ? 1 : 0

  name = "/${local.queue_worker_name}-${var.env_name}/adot-collector-config"
  type = "String"
  value = templatefile("${path.module}/../ecs-service/adot-collector-config.yaml.tpl", {
    aws_region = data.aws_region.current.region
    env_name   = var.env_name
    drop_spans = local.queue_worker_drop_span_expressions
  })

  description = "OpenTelemetry collector configuration for the ${local.queue_worker_name} ADOT sidecar in ${var.env_name}"
}

resource "aws_cloudwatch_log_group" "queue_worker" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Default AWS SSE is sufficient, no need for CM KMS.
  name              = local.queue_worker_log_group_name
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "queue_worker_adot" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Default AWS SSE is sufficient, no need for CM KMS.
  count             = var.enable_opentelemetry ? 1 : 0
  name              = "${local.queue_worker_log_group_name}/adot-collector"
  retention_in_days = 30
}

module "cribl_well_known" {
  source = "../well-known/cribl"
}

resource "aws_cloudwatch_log_subscription_filter" "via_cribl_to_splunk" {
  count = var.kinesis_subscription_role_arn != "" ? 1 : 0

  name = "via-cribl-to-splunk"

  log_group_name = aws_cloudwatch_log_group.queue_worker.name

  filter_pattern  = ""
  destination_arn = module.cribl_well_known.kinesis_destination_arns["eu-west-2"]
  distribution    = "ByLogStream"
  role_arn        = var.kinesis_subscription_role_arn
}
