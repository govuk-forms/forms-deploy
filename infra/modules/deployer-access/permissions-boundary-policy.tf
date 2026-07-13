resource "aws_iam_policy" "permissions_boundary" {
  name        = "deployer-${var.environment_name}-boundary"
  policy      = data.aws_iam_policy_document.permissions_boundary.json
  description = "Permissions boundary for non-human role"
  path        = "/permissions_boundaries/"
}

data "aws_iam_policy_document" "permissions_boundary" {
  #checkov:skip=CKV2_AWS_40:addressing in future commit
  #checkov:skip=CKV_AWS_107:addressing in future commit
  #checkov:skip=CKV_AWS_108:addressing in future commit
  #checkov:skip=CKV_AWS_109:addressing in future commit
  #checkov:skip=CKV_AWS_110:addressing in future commit
  #checkov:skip=CKV_AWS_111:addressing in future commit
  #checkov:skip=CKV_AWS_356:addressing in future commit
  statement {
    resources = ["*"]
    effect    = "Allow"
    actions = [
      "acm:*",
      "application-autoscaling:*",
      "application-signals:*",
      "cloudformation:*",
      "cloudfront:*",
      "cloudwatch:*",
      "codebuild:*",
      "codecommit:*",
      "codepipeline:*",
      "codestar-connections:*",
      "ec2:*",
      "ecr:*",
      "ecs:*",
      "elasticache:*",
      "elasticloadbalancing:*",
      "events:*",
      "guardduty:*",
      "iam:*",
      "kms:*",
      "lambda:*",
      "logs:*",
      "rds:*",
      "route53:*",
      "s3:*",
      "secretsmanager:*",
      "ses:*",
      "shield:*",
      "sns:*",
      "sqs:*",
      "ssm:*",
      "wafv2:*",
      "xray:*",
    ]

  }

  statement {
    sid    = "AllowAssumeRoleOnSpecificRoles"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    # forms-runner-ecs-task assumes submissions-to-s3; codebuild-e2e-tests assumes s3-end-to-end-test
    resources = [
      "arn:aws:iam::${var.account_id}:role/govuk-forms-submissions-to-s3-*",
      "arn:aws:iam::${var.account_id}:role/govuk-s3-end-to-end-test-*",
    ]
  }

  statement {
    sid    = "DenyBoundaryPolicyModification"
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion"
    ]
    resources = [
    "arn:aws:iam::${var.account_id}:policy/permissions_boundaries/deployer-${var.environment_name}-boundary"]
  }

  statement {
    sid    = "DenyBoundaryRemoval"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteUserPermissionBoundary"
    ]
    resources = ["*"]
  }
}
