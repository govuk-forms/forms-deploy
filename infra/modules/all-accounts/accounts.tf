locals {
  deploy_account_id      = "711966560482"
  integration_account_id = "842676007477"
  environment_accounts = {
    "development" = "498160065950",
    "staging"     = "972536609845",
    "production"  = "443944947292"
  }
}

output "deploy_account_id" {
  value = local.deploy_account_id
}

output "integration_account_id" {
  value = local.integration_account_id
}

output "environment_accounts_id" {
  value = local.environment_accounts
}

output "all_accounts_id" {
  value = merge(local.environment_accounts, { "deploy" : local.deploy_account_id, "integration" : local.integration_account_id })
}
