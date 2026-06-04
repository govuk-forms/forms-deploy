output "task_definition_name" {
  value = module.forms_admin.task_definition_name
}

output "target_group_arn" {
  value = module.forms_admin.target_group_arn
}

output "scheduled_task_families" {
  description = "ECS task definition families for scheduled forms-admin tasks (used by deploy pipeline to update images)."
  value       = module.forms_admin.scheduled_task_families
}
