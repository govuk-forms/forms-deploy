output "task_family" {
  value = aws_ecs_task_definition.this.family
}

output "container_name" {
  value = var.container_name
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.this.name
}
