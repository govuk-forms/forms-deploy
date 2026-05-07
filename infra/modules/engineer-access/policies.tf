data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_iam_policy" "access_aws_support_centre" {
  name        = "manage-aws-support-cases"
  path        = "/"
  description = "Permission to create, manage and resolve cases in the AWS Support Center"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["support:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "manage_deployments" {
  #checkov:skip=CKV_AWS_111: allow write access without constraint when needed
  #checkov:skip=CKV_AWS_290: allow write access without constraint when needed
  #checkov:skip=CKV_AWS_289: allow permissions management (PassRole) without constraint when needed
  #checkov:skip=CKV_AWS_355: allow resource * when needed

  name        = "manage-deployments"
  path        = "/"
  description = "Permission to manage deployements via CodePipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "PassRole"
        Action = [
          "iam:GetRole",
          "iam:PassRole",
          "codestar-connections:PassConnection"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid = "DisableEnableMainBranchDeploymentToAnyEnvironment"
        Action = [
          "codepipeline:DisableStageTransition",
          "codepipeline:EnableStageTransition",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:codepipeline:eu-west-2:${local.account_id}:*",
        ]
      },
      {
        Sid = "CodePipelineStartStopRetry"
        Action = [
          "codepipeline:RetryStageExecution",
          "codepipeline:StartPipelineExecution",
          "codepipeline:StopPipelineExecution",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid = "CodePipelineModifyDevBranches"
        Action = [
          "codepipeline:UpdatePipeline",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:codepipeline:eu-west-2:${local.account_id}:*"
        ]
      },
      {
        Sid = "CodeStarConnection"
        Action = [
          "codestar-connections:UseConnection",
        ]
        Effect   = "Allow"
        Resource = var.codestar_connection_arn
      },
    ]
  })
}

resource "aws_iam_policy" "query_rds_with_data_api" {
  count       = var.allow_rds_data_api_access ? 1 : 0
  name        = "query-rds-with-data-api"
  path        = "/"
  description = "Permission to use the data api to query RDS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "DataApi"
        Action = [
          "rds-data:ExecuteStatement",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:rds:eu-west-2:${local.account_id}:cluster:aurora-v2-cluster-*"
      },
      {
        Sid = "SecretsManager"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:secretsmanager:eu-west-2:${local.account_id}:secret:data-api/${var.env_name}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_policy" "manage_ecs_task" {
  count       = var.allow_ecs_task_usage ? 1 : 0
  name        = "manage-ecs-task"
  path        = "/"
  description = "Permission to run/stop task on ECS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:RunTask",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:ecs:eu-west-2:${local.account_id}:task-definition/*_forms-admin",
          "arn:aws:ecs:eu-west-2:${local.account_id}:task-definition/*_forms-runner",
          "arn:aws:ecs:eu-west-2:${local.account_id}:task-definition/*_forms-admin:*",
          "arn:aws:ecs:eu-west-2:${local.account_id}:task-definition/*_forms-runner:*",
        ]
      },
      {
        Action = [
          "iam:PassRole",
        ],
        Effect = "Allow"
        Resource = [
          "arn:aws:iam::${local.account_id}:role/*-forms-admin-ecs-task",
          "arn:aws:iam::${local.account_id}:role/*-forms-admin-ecs-task-execution",
          "arn:aws:iam::${local.account_id}:role/*-forms-runner-ecs-task",
          "arn:aws:iam::${local.account_id}:role/*-forms-runner-ecs-task-execution",
        ]
      },
      {
        Action = [
          "ecs:StopTask",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:ecs:eu-west-2:${local.account_id}:task/forms-*/*",
        ]
      },
    ]
  })
}

resource "aws_iam_policy" "manage_parameter_store" {
  #checkov:skip=CKV_AWS_290:We have additional restrictions elsewhere
  name        = "manage-parameter-store"
  path        = "/"
  description = "Permission to create, delete and modify parameter store values"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:PutParameter",
          "ssm:DeleteParameter",
        ]
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Action = [
          "ssm:PutParameter",
          "ssm:DeleteParameter",
        ]
        Effect = "Deny"
        Resource = [
          "arn:aws:ssm:*:*:parameter/${var.env_name}/database/root-password"
        ]
      },
    ]
  })
}

resource "aws_iam_policy" "manage_dashboards_and_maintenance_page" {
  #checkov:skip=CKV_AWS_290: We're OK with unlimited access to CloudWatch dashboards
  #checkov:skip=CKV_AWS_355: We're OK with unlimited access to CloudWatch dashboards
  name        = "manage-dashboards-and-maintenance-page"
  path        = "/"
  description = "Manage CloudWatch dashboards and maintenance page"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutDashboard",
          "cloudwatch:DeleteDashboards"
        ]
        Effect   = "Allow"
        Resource = ["*"]
      }
    ]

    Statement = [
      {
        Action = [
          "ecs:DeregisterTaskDefinition",
        ]
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:TagResource"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:ecs:eu-west-2:${local.account_id}:task-definition/${var.env_name}_forms-admin:*",
          "arn:aws:ecs:eu-west-2:${local.account_id}:task-definition/${var.env_name}_forms-runner:*"
        ]
      },
      {
        Action = [
          "ecs:UpdateService"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:ecs:eu-west-2:${local.account_id}:service/forms-${var.env_name}/forms-admin",
          "arn:aws:ecs:eu-west-2:${local.account_id}:service/forms-${var.env_name}/forms-runner"
        ]
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::gds-forms-${var.environment_type}-tfstate",
          "arn:aws:s3:::gds-forms-${var.environment_type}-tfstate/*"
        ]
      },
    ]
  })
}

resource "aws_iam_policy" "deny_parameter_store" {
  name        = "deny-parameter-store-read-access"
  path        = "/"
  description = "Deny viewing secrets in parameter store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter*",
        ]
        Effect   = "Deny"
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_policy" "lock_state_files" {
  name = "allow-locking-state-files"
  path = "/"

  description = "Allow locking state files"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.state_file_bucket_name}/*.tflock"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "get_ux_customisation" {
  name = "allow-get-uxc"
  path = "/"

  description = "Allow access to AWS Console UX Customisation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "uxc:GetAccountColor",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "get_usage_data" {
  name = "allow-get-usage_data"
  path = "/"

  description = "Allow access to AWS Sustainability and usage of Cost Explorer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sustainability:GetCarbonFootprintSummary",
          "sustainability:GetEstimatedCarbonEmissions",
          "sustainability:GetEstimatedCarbonEmissionsDimensionValues",
        ]
        Effect = "Allow"
        Resource = [
          "*"
        ]
      },
      {
        Action = [
          "ce:GetCommitmentPurchaseAnalysis",
        ]
        Effect = "Allow"
        Resource = [
          "*"
        ]
      }
    ]
  })
}
