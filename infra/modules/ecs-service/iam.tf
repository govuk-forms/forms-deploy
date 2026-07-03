resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.env_name}-${var.application}-ecs-task"
  description        = "Used by ${var.application} tasks when running"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_role_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_role_assume_role" {
  statement {
    sid     = "AllowECS"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }

  # This is a workaround.
  #
  # AWS policy principals must have >0 elements, but our list might be empty.
  # So we use a dynamic block to exclude the statement altogether if it is.
  #
  # The use of "for_each" substitutes for the lack of a built-in conditional
  # for dynamic blocks.
  dynamic "statement" {
    for_each = length(var.additional_task_role_assumers) > 0 ? [1] : []

    content {
      sid     = "AllowOthers"
      actions = ["sts:AssumeRole"]
      effect  = "Allow"

      principals {
        type        = "AWS"
        identifiers = var.additional_task_role_assumers
      }
    }
  }
}

resource "aws_iam_policy" "ecs_task_policy" {
  count  = var.ecs_task_role_policy_json == "" ? 0 : 1
  name   = "${var.env_name}-${var.application}-ecs-task-policy"
  policy = var.ecs_task_role_policy_json
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment" {
  count      = var.ecs_task_role_policy_json == "" ? 0 : 1
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy[0].arn
}

resource "aws_iam_role" "ecs_task_exec_role" {
  name               = "${var.env_name}-${var.application}-ecs-task-execution"
  description        = "Used by ECS to create ${var.application} task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_exec_role_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_exec_role_assume_role" {
  statement {
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

resource "aws_iam_role_policy_attachment" "ecs_task_exec_additional_policies" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = aws_iam_policy.ecs_task_exec_additional_policy.arn
}

resource "aws_iam_policy" "ecs_task_exec_additional_policy" {
  name   = "${var.env_name}-${var.application}-ecs-task-execution-additional"
  policy = data.aws_iam_policy_document.ecs_task_exec_additional_policies.json
}

data "aws_iam_policy_document" "ecs_task_exec_additional_policies" {
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
        for secret in flatten(var.secrets) : secret.valueFrom
        if startswith(secret.valueFrom, "arn:aws:ssm")
      ],
      var.enable_opentelemetry ? [aws_ssm_parameter.adot_collector_config[0].arn] : []
    )
    effect = "Allow"
  }
}
