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
# nothing in AWS beyond logging, reading its token and keeping its cache. It
# never reads the App's key: the orchestrator mints the token.
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
    actions   = ["s3:GetBucketLocation", "s3:GetBucketAcl", "s3:ListBucket"]
    resources = [module.cache_bucket.arn]
    effect    = "Allow"
  }

  statement {
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
    resources = ["${module.cache_bucket.arn}/*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["ssm:GetParameters"]
    resources = ["arn:aws:ssm:${local.aws_region}:${local.aws_account_id}:parameter${local.token_parameter_prefix}/*"]
    effect    = "Allow"
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

# EventBridge IAM Role and Policies. It is only needed to publish failures, as
# the rules that start the orchestrator use its resource policy.

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
  count              = var.failure_topic_arn != null ? 1 : 0
  name               = "eventbridge-renovate"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

data "aws_iam_policy_document" "eventbridge" {
  count = var.failure_topic_arn != null ? 1 : 0

  statement {
    actions   = ["sns:Publish"]
    resources = [var.failure_topic_arn]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "eventbridge" {
  count  = var.failure_topic_arn != null ? 1 : 0
  name   = "eventbridge-renovate"
  path   = "/"
  policy = data.aws_iam_policy_document.eventbridge[0].json
}

resource "aws_iam_role_policy_attachment" "eventbridge" {
  count      = var.failure_topic_arn != null ? 1 : 0
  policy_arn = aws_iam_policy.eventbridge[0].arn
  role       = aws_iam_role.eventbridge[0].id
}
