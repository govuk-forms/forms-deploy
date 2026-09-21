data "aws_caller_identity" "current" {}

resource "aws_backup_plan" "daily_cross_account" {
  name = "daily-cross-account"

  rule {
    rule_name         = "daily-cross-account"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(8 6 * * ? *)"

    lifecycle {
      delete_after = 3
    }
  }
}

resource "aws_backup_vault" "main" {
  name = "main"
}

resource "aws_backup_vault_policy" "main_backup" {
  backup_vault_name = aws_backup_vault.main.name
  policy            = data.aws_iam_policy_document.allow_backup.json
}

data "aws_iam_policy_document" "allow_backup" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions = [
      "backup:DescribeBackupVault",
      "backup:PutBackupVaultAccessPolicy",
      "backup:GetBackupVaultAccessPolicy",
      "backup:StartBackupJob",
      "backup:GetBackupVaultNotifications",
      "backup:PutBackupVaultNotifications",
    ]

    resources = [aws_backup_vault.main.arn]
  }
}


# Selection
resource "aws_backup_selection" "aurora" {
  iam_role_arn = aws_iam_role.backup_assume_role.arn
  name         = "aurora"
  plan_id      = aws_backup_plan.daily_cross_account.id

  resources = [
    data.terraform_remote_state.rds.outputs.forms_admin_aurora_cluster_arn,
    data.terraform_remote_state.rds.outputs.forms_runner_aurora_cluster_arn
  ]
}

data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "backup_assume_role" {
  name               = "backup-assume-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
}

resource "aws_iam_role_policy_attachment" "backup_service_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_assume_role.name
}

