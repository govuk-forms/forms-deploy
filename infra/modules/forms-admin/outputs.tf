output "task_definition_name" {
  value = module.ecs_service.task_container_definition.name
}

output "target_group_arn" {
  value = module.ecs_service.target_group_arn
}

output "scheduled_task_families" {
  description = "ECS task definition families for scheduled forms-admin tasks (used by deploy pipeline to update images)."
  value       = [for task in module.scheduled_tasks : task.task_family]
}
