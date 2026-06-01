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
    ]

  }

  statement {
    sid    = "AllowAssumeRoleOnSpecificRoles"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      // Include only specific roles - do we just hardcode these? either way, we should make sure the roles themselves have a permissions boundary
      // does this include human roles and the end-to-end-test role?
      //specific roles in own account. Other accounts *
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
