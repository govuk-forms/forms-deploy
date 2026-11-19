output "admin_role_arns" {
  value = values(module.admin_role)[*].role_arn
}
