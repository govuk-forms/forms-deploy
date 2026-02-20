resource "aws_ecs_cluster" "forms" {
  name = "forms-${var.env_name}"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }
}


## ECS Events Role
## This a common role used by EventBridge to run ECS tasks. Only needs to be created once per account.

data "aws_iam_policy_document" "ecs_events_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_events" {
  name               = "ecsEventsRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_events_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_events_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
  role       = aws_iam_role.ecs_events.name
}
