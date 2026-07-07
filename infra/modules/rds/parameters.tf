# The database passwords were manually generated when creating the environments
# Note that the RDS docs use the terminology 'master password' - we are using 'root password'
resource "aws_ssm_parameter" "database_password_for_root_user" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  name        = "/${var.identifier}/database/root-password"
  description = "Password for the default root user created by Terraform"
  type        = "SecureString"
  value       = "dummy-value"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "aws_ssm_parameter" "database_password" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  for_each = var.apps_list

  name        = "/${each.key}-${var.env_name}/database/password"
  description = "Password for the ${each.value.username} user in the ${each.key} database in the ${var.env_name} environment"
  type        = "SecureString"
  value       = "dummy-value"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

# TODO: delete `data_api_credentials` secrets after migrating to autolocate secrets.
resource "aws_secretsmanager_secret" "data_api_credentials" {
  #checkov:skip=CKV_AWS_149:The secret is already using the default key, which is sufficient
  #checkov:skip=CKV2_AWS_57:We're setting this manually from an authoritative source, so rotation would be actively harmful
  for_each = var.apps_list

  name        = "data-api/${var.env_name}/${each.key}/rds-credentials"
  description = "Data API credentials for ${each.key} in ${var.env_name} environment"
}

resource "aws_secretsmanager_secret_version" "data_api_credentials" {
  for_each = var.apps_list

  secret_id = aws_secretsmanager_secret.data_api_credentials[each.key].id
  secret_string = jsonencode({
    username = each.value.username
    password = aws_ssm_parameter.database_password[each.key].value
  })
}

locals {
  force_ssl_connections = var.force_ssl_connections ? "verify-full" : "prefer"
}

resource "aws_ssm_parameter" "database_url" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key
  #checkov:skip=CKV2_FORMS_AWS_7:Database URLs should update when passwords or endpoints change
  for_each = var.apps_list

  name        = "/${each.key}-${var.env_name}/database/url"
  description = "URL for connecting to the ${each.key} database in the ${var.env_name} environment using the ${each.value.username} user"
  type        = "SecureString"
  value = format("postgres://%s:%s@%s/%s?sslmode=%s",
    each.value.username,
    aws_ssm_parameter.database_password[each.key].value,
    aws_rds_cluster.cluster_aurora_v2.endpoint,
    each.key,
    local.force_ssl_connections
  )
}

locals {
  autolocate_secret_timestamp = "1778583245"
  database_creds = merge(
    {
      for k, v in var.apps_list : k => merge(v, {
        password = aws_ssm_parameter.database_password[k].value
      })
    },
    {
      root = {
        username = "root"
        password = aws_ssm_parameter.database_password_for_root_user.value
      }
    }
  )
}

resource "aws_secretsmanager_secret" "data_api_credentials_autolocate" {
  #checkov:skip=CKV_AWS_149:The secret is already using the default key, which is sufficient
  #checkov:skip=CKV2_AWS_57:We're setting this manually from an authoritative source, so rotation would be actively harmful

  for_each = local.database_creds

  name        = "rds-db-credentials/${aws_rds_cluster.cluster_aurora_v2.cluster_resource_id}/${each.key}"
  description = "RDS database ${each.value.username} credentials for ${aws_rds_cluster.cluster_aurora_v2.id}"
}

resource "aws_secretsmanager_secret_version" "data_api_credentials_autolocate" {
  for_each = local.database_creds

  secret_id = aws_secretsmanager_secret.data_api_credentials_autolocate[each.key].id
  secret_string = jsonencode({
    // Preamble: Data API adds these fields when creating secrets, so let's include them as well.
    dbInstanceIdentifier = aws_rds_cluster.cluster_aurora_v2.id
    engine               = aws_rds_cluster.cluster_aurora_v2.engine
    host                 = aws_rds_cluster.cluster_aurora_v2.endpoint
    port                 = aws_rds_cluster.cluster_aurora_v2.port
    resourceId           = aws_rds_cluster.cluster_aurora_v2.cluster_resource_id

    username = each.value.username
    password = each.value.password
  })
}
