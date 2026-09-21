
module "other_accounts" {
  source = "../../../modules/all-accounts"
}

# Use this vault for copies of backups created in other accounts
resource "aws_backup_vault" "copy" {
  name = "copy"
}

resource "aws_backup_vault_policy" "copy_backup" {
  backup_vault_name = aws_backup_vault.copy.name
  policy            = data.aws_iam_policy_document.allow_backup_copy.json
}

# Allow all environment accounts to copy backups into this vault
data "aws_iam_policy_document" "allow_backup_copy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [for _, id in module.other_accounts.environment_accounts_id : "arn:aws:iam::${id}:root"]
    }

    actions = [
      "backup:CopyIntoBackupVault"
    ]

    resources = [aws_backup_vault.copy.arn]
  }
}