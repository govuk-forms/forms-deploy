output "forms_admin_aurora_cluster_arn" {
  value = module.rds.aurora_cluster_arn
}

output "forms_runner_aurora_cluster_arn" {
  value = module.forms_runner_rds.aurora_cluster_arn
}