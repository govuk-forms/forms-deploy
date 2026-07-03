output "service" {
  value = aws_ecs_service.app_service
}
output "task_definition" {
  value = aws_ecs_task_definition.task
}

output "task_container_definition" {
  value = merge(local.task_container_definition, {
    healthCheck = null
  })
  description = "The computed container definition for the task, after applying any overrides. Container healthcheck is not included as things that use this output should set their own healthcheck."
}

output "task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

output "application_log_group_name" {
  value = aws_cloudwatch_log_group.log.name
}

output "task_definition_family" {
  value = aws_ecs_task_definition.task.family
}

output "target_group_arn" {
  value = aws_lb_target_group.tg.arn
}

output "adot_image" {
  value = var.adot_image
}

output "adot_collector_config_parameter_arn" {
  value       = try(aws_ssm_parameter.adot_collector_config[0].arn, null)
  description = "SSM parameter ARN containing the ADOT collector configuration"
}

output "adot_sidecar_cpu" {
  value = var.adot_sidecar_cpu
}

output "adot_sidecar_memory" {
  value = var.adot_sidecar_memory
}
