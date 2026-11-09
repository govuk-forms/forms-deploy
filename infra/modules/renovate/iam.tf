# CodeBuild IAM Role and Policies

data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "codebuild-renovate"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
}

# Renovate only talks to GitHub and the package registries, so the role can do
# nothing in AWS beyond logging and reading its two parameters.
data "aws_iam_policy_document" "codebuild" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.renovate.arn}:*"]
    effect    = "Allow"
  }

  statement {
    actions = ["ssm:GetParameters"]
    resources = [
      aws_ssm_parameter.github_app_id.arn,
      aws_ssm_parameter.github_app_private_key.arn,
    ]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "codebuild" {
  name   = "codebuild-renovate"
  path   = "/"
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  policy_arn = aws_iam_policy.codebuild.arn
  role       = aws_iam_role.codebuild.id
}

# EventBridge IAM Role and Policies

data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge" {
  name               = "eventbridge-renovate"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

data "aws_iam_policy_document" "eventbridge" {
  statement {
    actions   = ["codebuild:StartBuild"]
    resources = [aws_codebuild_project.renovate.arn]
    effect    = "Allow"
  }

  dynamic "statement" {
    for_each = var.failure_topic_arn != null ? [1] : []
    content {
      actions   = ["sns:Publish"]
      resources = [var.failure_topic_arn]
      effect    = "Allow"
    }
  }
}

resource "aws_iam_policy" "eventbridge" {
  name   = "eventbridge-renovate"
  path   = "/"
  policy = data.aws_iam_policy_document.eventbridge.json
}

resource "aws_iam_role_policy_attachment" "eventbridge" {
  policy_arn = aws_iam_policy.eventbridge.arn
  role       = aws_iam_role.eventbridge.id
}
