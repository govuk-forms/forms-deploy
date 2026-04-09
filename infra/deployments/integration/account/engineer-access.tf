module "users" {
  source = "../../../modules/users"
}

module "common_values" {
  source = "../../../modules/common-values"
}

locals {
  ip_restrictions = var.require_vpn_to_access ? module.common_values.vpn_ip_addresses : []

  admin_users    = module.users.with_role["integration_admin"]
  suppport_users = module.users.with_role["integration_support"]
  readonly_users = module.users.with_role["integration_readonly"]
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
          "arn:aws:s3:::${var.bucket}/*.tflock"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "get_sustainability_data" {
  name = "allow-get-sustainability_data"
  path = "/"

  description = "Allow access to AWS Sustainability"

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
      }
    ]
  })
}


module "admin_role" {
  for_each = toset(local.admin_users)

  source          = "../../../modules/gds-user-role/"
  email           = "${each.value}@digital.cabinet-office.gov.uk"
  role_suffix     = "admin"
  iam_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  ip_restrictions = local.ip_restrictions
}

module "support_role" {
  for_each = toset(concat(local.admin_users, local.suppport_users))

  source      = "../../../modules/gds-user-role/"
  email       = "${each.value}@digital.cabinet-office.gov.uk"
  role_suffix = "support"
  iam_policy_arns = [
    aws_iam_policy.lock_state_files.arn,
    aws_iam_policy.get_sustainability_data.arn
  ]
  ip_restrictions = local.ip_restrictions
}

module "readonly_role" {
  for_each = toset(concat(local.admin_users, local.suppport_users, local.readonly_users))

  source      = "../../../modules/gds-user-role/"
  email       = "${each.value}@digital.cabinet-office.gov.uk"
  role_suffix = "readonly"
  iam_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    aws_iam_policy.lock_state_files.arn,
    aws_iam_policy.get_sustainability_data.arn
  ]
  ip_restrictions = local.ip_restrictions
}

module "pentester_role" {
  for_each = toset(var.pentester_email_addresses)

  source      = "../../../modules/gds-user-role/"
  email       = each.value
  role_suffix = "pentester"
  iam_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    "arn:aws:iam::aws:policy/SecurityAudit",
    aws_iam_policy.deny_parameter_store.arn
  ]
  ip_restrictions = var.pentester_cidr_ranges
}
