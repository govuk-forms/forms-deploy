data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  project_name = "review-${var.application_name}-${var.action}"
}

resource "aws_iam_role" "codebuild" {
  name = local.project_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  role   = aws_iam_role.codebuild.name
  policy = data.aws_iam_policy_document.codebuild.json
}

data "aws_iam_policy_document" "codebuild" {
  # CodeConnections for GitHub access
  statement {
    actions   = ["codeconnections:GetConnectionToken", "codeconnections:GetConnection"]
    resources = [var.codeconnection_arn]
  }

  # CloudWatch Logs
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.codebuild.arn}:*"]
  }

  # ECS Services
  statement {
    actions = ["ecs:*Service", "ecs:*Services", "ecs:TagResource"]
    resources = [
      var.ecs_cluster_arn,
      "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.application_name}-pr-*"
    ]
  }

  # ECS Task Definitions
  statement {
    actions   = ["ecs:*TaskDefinition", "ecs:*TaskDefinitions", "ecs:TagResource"]
    resources = ["arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task-definition/${var.application_name}-pr-*"]
  }

  statement {
    actions   = ["ecs:DeregisterTaskDefinition", "ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  # Terraform State - Read
  statement {
    actions = ["s3:GetObject", "s3:GetObjectVersion", "s3:HeadObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::gds-forms-integration-tfstate",
      "arn:aws:s3:::gds-forms-integration-tfstate/review.tfstate",
      "arn:aws:s3:::gds-forms-integration-tfstate/review-apps/${var.application_name}/pr-*.tfstate"
    ]
  }

  # Terraform State - Write
  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::gds-forms-integration-tfstate/review-apps/${var.application_name}/pr-*.tfstate"]
  }

  # Terraform State Lock
  statement {
    actions   = ["s3:DeleteObject"]
    resources = ["arn:aws:s3:::gds-forms-integration-tfstate/review-apps/${var.application_name}/pr-*.tflock"]
  }

  # ECR - Local (read-only, image already pushed by GitHub Actions)
  statement {
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = [var.ecr_repository_arn]
  }

  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR - Deploy account (for base images)
  statement {
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    resources = ["arn:aws:ecr:${data.aws_region.current.region}:${var.deploy_account_id}:repository/*"]
  }

  # IAM PassRole
  statement {
    actions   = ["iam:PassRole"]
    resources = concat([var.task_execution_role_arn, var.autoscaling_role_arn], var.task_role_arns)
  }

  # Application Auto Scaling
  statement {
    actions = [
      "application-autoscaling:*ScalableTarget",
      "application-autoscaling:*ScalableTargets",
      "application-autoscaling:*ScheduledAction",
      "application-autoscaling:*ScheduledActions",
      "application-autoscaling:*ScalingPolicy",
      "application-autoscaling:*ScalingPolicies",
      "application-autoscaling:ListTagsForResource",
      "application-autoscaling:TagResource",
      "application-autoscaling:UntagResource"
    ]
    resources = ["arn:aws:application-autoscaling:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:scalable-target/*"]
  }

  statement {
    actions   = ["application-autoscaling:DescribeScalableTargets", "application-autoscaling:DescribeScalingPolicies", "application-autoscaling:DescribeScheduledActions"]
    resources = ["*"]
  }

  # S3 Artifacts - Write
  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.artifacts_bucket_name}/*/${local.project_name}/outputs.json"]
  }

  # S3 Assets - sync built assets from the container image (deploy only)
  dynamic "statement" {
    for_each = var.action == "deploy" ? [1] : []
    content {
      actions   = ["s3:ListBucket"]
      resources = ["arn:aws:s3:::${var.assets_bucket_name}"]
    }
  }

  dynamic "statement" {
    for_each = var.action == "deploy" ? [1] : []
    content {
      actions   = ["s3:PutObject"]
      resources = ["arn:aws:s3:::${var.assets_bucket_name}/assets/*"]
    }
  }
}

resource "aws_codebuild_project" "this" {
  # checkov:skip=CKV_AWS_314:Logs are streamed to GitHub Actions via the aws-codebuild-run-build action
  # checkov:skip=CKV_AWS_147:Review app infrastructure is ephemeral and non-production; CMK encryption not required
  name         = local.project_name
  service_role = aws_iam_role.codebuild.arn

  dynamic "artifacts" {
    for_each = var.action == "deploy" ? [1] : []
    content {
      type           = "S3"
      location       = var.artifacts_bucket_name
      name           = local.project_name
      namespace_type = "BUILD_ID"
      packaging      = "NONE"
    }
  }
  dynamic "artifacts" {
    for_each = var.action == "destroy" ? [1] : []
    content {
      type = "NO_ARTIFACTS"
    }
  }

  # The buildspec files also require PR_NUMBER and CONTAINER_IMAGE environment
  # variables, which are passed at runtime when GitHub Actions triggers the build
  # using the aws-codebuild-run-build action's env-vars-for-codebuild parameter.
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-aarch64-standard:4.0"
    type         = "ARM_CONTAINER"

    environment_variable {
      name  = "APPLICATION_NAME"
      value = var.application_name
    }

    environment_variable {
      name  = "ACTION"
      value = var.action
    }

    environment_variable {
      name  = "ASSETS_BUCKET"
      value = var.assets_bucket_name
    }
  }

  source {
    type     = "GITHUB"
    location = var.github_repository

    auth {
      type     = "CODECONNECTIONS"
      resource = var.codeconnection_arn
    }

    buildspec = var.action == "deploy" ? file("${path.module}/buildspec-deploy.yml") : file("${path.module}/buildspec-destroy.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild.name
    }
  }
}
