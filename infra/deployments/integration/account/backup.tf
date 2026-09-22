
module "other_accounts" {
  source = "../../../modules/all-accounts"
}

# Use this vault for copies of backups created in other accounts
resource "aws_backup_vault" "copy" {
  name = "copy"
  # We have to specify the kms key used in encrypting the backup. This means we either need to setup a "copy" vault per environment account, or share a kms across all environment accounts. Although since we only care about production backups we can safely assume that we only need 1 kms key
  kms_key_arn = "arn:aws:kms:eu-west-2:498160065950:key/4f4c4f42-3deb-4f0f-9903-8cf88ccf35ef"
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