module "renovate" {
  source = "../../../modules/renovate"

  schedule_expression = var.renovate_schedule
  failure_topic_arn   = module.chatbot_well_known.infra_notifications_topic_arn
}
