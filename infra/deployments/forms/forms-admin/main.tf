variable "forms_admin_image_tag" {
  type        = string
  description = "The image tag to deploy"
  nullable    = true
  default     = null
}

module "forms_admin" {
  source                            = "../../../modules/forms-admin"
  env_name                          = var.environment_name
  root_domain                       = var.root_domain
  container_registry                = var.container_registry
  image_tag                         = var.forms_admin_image_tag
  cpu                               = var.forms_admin_settings.cpu
  memory                            = var.forms_admin_settings.memory
  min_capacity                      = var.forms_admin_settings.min_capacity
  max_capacity                      = var.forms_admin_settings.max_capacity
  runner_base                       = "https://submit.${var.root_domain}"
  govuk_app_domain                  = var.forms_admin_settings.govuk_app_domain
  enable_maintenance_mode           = var.forms_admin_settings.enable_maintenance_mode
  forms_product_page_support_url    = var.environmental_settings.forms_product_page_support_url
  auth_provider                     = var.forms_admin_settings.auth_provider
  previous_auth_provider            = var.forms_admin_settings.previous_auth_provider
  cloudwatch_metrics_enabled        = var.forms_admin_settings.cloudwatch_metrics_enabled
  analytics_enabled                 = var.forms_admin_settings.analytics_enabled
  enable_opentelemetry              = var.forms_admin_settings.enable_opentelemetry
  opentelemetry_head_sampler_ratio  = var.forms_runner_settings.opentelemetry_head_sampler_ratio
  act_as_user_enabled               = var.forms_admin_settings.act_as_user_enabled
  enable_mailchimp_sync             = var.forms_admin_settings.synchronize_to_mailchimp
  enable_organisations_sync         = var.forms_admin_settings.synchronize_orgs_from_govuk
  send_filler_answers               = var.forms_admin_settings.send_filler_answers
  deploy_account_id                 = var.deploy_account_id
  vpc_id                            = data.terraform_remote_state.forms_environment.outputs.vpc_id
  vpc_cidr_block                    = data.terraform_remote_state.forms_environment.outputs.vpc_cidr_block
  private_subnet_ids                = data.terraform_remote_state.forms_environment.outputs.private_subnet_ids
  eventbridge_dead_letter_queue_arn = data.terraform_remote_state.forms_environment.outputs.eventbridge_dead_letter_queue_arn
  zendesk_sns_topic_arn             = data.terraform_remote_state.forms_environment.outputs.zendesk_alert_eu_west_2_topic_arn
  ecs_cluster_arn                   = data.terraform_remote_state.forms_environment.outputs.ecs_cluster_arn
  alb_arn_suffix                    = data.terraform_remote_state.forms_environment.outputs.alb_arn_suffix
  alb_listener_arn                  = data.terraform_remote_state.forms_environment.outputs.alb_main_listener_arn
  internal_alb_listener_arn         = data.terraform_remote_state.forms_environment.outputs.internal_alb_listener_arn
  cloudfront_secret                 = data.terraform_remote_state.forms_environment.outputs.cloudfront_secret
  kinesis_subscription_role_arn     = data.terraform_remote_state.account.outputs.kinesis_subscription_role_arn
}
