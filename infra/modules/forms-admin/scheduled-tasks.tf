locals {
  scheduled_tasks = {}
}

module "scheduled_tasks" {
  for_each = {
    for task_name, task in local.scheduled_tasks : task_name => task
    if task.enabled
  }
  source   = "../ecs-scheduled-task"

  task_name                         = "forms-admin-${replace(each.key, "_", "-")}"
  schedule_expression               = each.value.schedule_expression
  command                           = each.value.command
  ecs_cluster_arn                   = var.ecs_cluster_arn
  scheduler_role_arn                = var.ecs_events_role_arn
  eventbridge_dead_letter_queue_arn = var.eventbridge_dead_letter_queue_arn
  base_task_container_definition    = module.ecs_service.task_container_definition
  application_log_group_name        = module.ecs_service.application_log_group_name
  execution_role_arn                = module.ecs_service.task_definition.execution_role_arn
  task_role_arn                     = module.ecs_service.task_definition.task_role_arn
  requires_compatibilities          = module.ecs_service.task_definition.requires_compatibilities
  cpu                               = module.ecs_service.task_definition.cpu
  memory                            = module.ecs_service.task_definition.memory
  network_security_groups           = module.ecs_service.service.network_configuration[0].security_groups
  network_subnets                   = module.ecs_service.service.network_configuration[0].subnets
}
