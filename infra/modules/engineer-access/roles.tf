module "common_values" {
  source = "../common-values"
}

locals {
  vpn_ip_restrictions = var.vpn ? module.common_values.vpn_ip_addresses : []
}

module "admin_role" {
  for_each = toset(var.admins)

  source          = "../gds-user-role/"
  email           = "${each.value}@digital.cabinet-office.gov.uk"
  role_suffix     = "admin"
  iam_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  ip_restrictions = local.vpn_ip_restrictions
}

module "support_role" {
  for_each = toset(concat(var.admins, var.support))

  source      = "../gds-user-role/"
  email       = "${each.value}@digital.cabinet-office.gov.uk"
  role_suffix = "support"
  iam_policy_arns = flatten([
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    aws_iam_policy.access_aws_support_centre.arn,
    aws_iam_policy.manage_parameter_store.arn,
    aws_iam_policy.manage_dashboards_and_maintenance_page.arn,
    aws_iam_policy.manage_deployments.arn,
    aws_iam_policy.lock_state_files.arn,
    var.allow_rds_data_api_access ? [aws_iam_policy.query_rds_with_data_api[0].arn] : [],
    var.allow_ecs_task_usage ? [aws_iam_policy.manage_ecs_task[0].arn] : [],
    aws_iam_policy.get_ux_customisation.arn,
    aws_iam_policy.get_sustainability_data.arn,
  ])
  ip_restrictions = local.vpn_ip_restrictions
}

module "readonly_role" {
  for_each = toset(concat(var.admins, var.support, var.readonly))

  source      = "../gds-user-role/"
  email       = "${each.value}@digital.cabinet-office.gov.uk"
  role_suffix = "readonly"
  iam_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    aws_iam_policy.lock_state_files.arn,
    aws_iam_policy.get_ux_customisation.arn,
    aws_iam_policy.get_sustainability_data.arn,
  ]
  ip_restrictions = local.vpn_ip_restrictions
}


module "pentester_role" {
  for_each = toset(var.pentesters)

  source      = "../gds-user-role/"
  email       = each.value #Cannot assume the domain is GDS for external testers
  role_suffix = "pentester"
  iam_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    "arn:aws:iam::aws:policy/SecurityAudit",
    aws_iam_policy.deny_parameter_store.arn,
    aws_iam_policy.get_ux_customisation.arn,
  ]
  ip_restrictions = var.pentester_cidrs
}
