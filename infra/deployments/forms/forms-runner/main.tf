variable "forms_runner_image_tag" {
  type        = string
  description = "The image tag to deploy"
  nullable    = true
  default     = null
}

module "forms_people" {
  source = "../../../modules/users"
}

data "aws_iam_role" "readonly_people_roles" {
  # Readonly roles are made for each of the people in these lists
  for_each = toset(concat(
    module.forms_people.with_role["deploy_admin"],
    module.forms_people.with_role["deploy_support"],
    module.forms_people.with_role["deploy_readonly"]
  ))
  name = "${each.value}-readonly"
}

locals {
  allowed_submissions_to_s3_role_assumers = var.forms_runner_settings.allow_human_readonly_roles_to_assume_submissions_to_s3_role ? (
    [for role in data.aws_iam_role.readonly_people_roles : role.arn]
    ) : (
    []
  )

  allowed_forms_runner_role_assumers = var.forms_runner_settings.allow_human_readonly_roles_to_assume_submissions_to_runner_role ? (
    [for role in data.aws_iam_role.readonly_people_roles : role.arn]
    ) : (
    []
  )
}

module "forms_runner" {
  source                                             = "../../../modules/forms-runner"
  env_name                                           = var.environment_name
  environment_type                                   = var.environment_type
  root_domain                                        = var.root_domain
  image_tag                                          = var.forms_runner_image_tag
  cpu                                                = var.forms_runner_settings.cpu
  memory                                             = var.forms_runner_settings.memory
  min_capacity                                       = var.forms_runner_settings.min_capacity
  max_capacity                                       = var.forms_runner_settings.max_capacity
  api_base_url                                       = "http://admin.internal.${var.root_domain}"
  admin_base_url                                     = "https://admin.${var.root_domain}"
  product_page_base_url                              = "https://${var.root_domain}"
  enable_maintenance_mode                            = var.forms_runner_settings.enable_maintenance_mode
  cloudwatch_metrics_enabled                         = var.forms_runner_settings.cloudwatch_metrics_enabled
  analytics_enabled                                  = var.forms_runner_settings.analytics_enabled
  copy_of_answers_enabled                            = var.forms_runner_settings.copy_of_answers_enabled
  enable_opentelemetry                               = var.forms_runner_settings.enable_opentelemetry
  opentelemetry_head_sampler_ratio                   = var.forms_runner_settings.opentelemetry_head_sampler_ratio
  deploy_account_id                                  = var.deploy_account_id
  ses_submission_email_from_email_address            = var.forms_runner_settings.ses_submission_email_from_email_address
  ses_submission_email_reply_to_email_address        = var.forms_runner_settings.ses_submission_email_reply_to_email_address
  ses_submissions_configuration_set_name             = data.terraform_remote_state.forms_ses.outputs.form_submissions_configuration_set_name
  ses_confirmations_configuration_set_name           = data.terraform_remote_state.forms_ses.outputs.form_confirmations_configuration_set_name
  govuk_one_login_base_url                           = var.forms_runner_settings.govuk_one_login_base_url
  additional_submissions_to_s3_role_assumers         = local.allowed_submissions_to_s3_role_assumers
  additional_forms_runner_role_assumers              = local.allowed_forms_runner_role_assumers
  elasticache_port                                   = data.terraform_remote_state.redis.outputs.elasticache_port
  elasticache_primary_endpoint_address               = data.terraform_remote_state.redis.outputs.elasticache_primary_endpoint_address
  container_repository                               = "${var.container_registry}/forms-runner-deploy"
  vpc_id                                             = data.terraform_remote_state.forms_environment.outputs.vpc_id
  vpc_cidr_block                                     = data.terraform_remote_state.forms_environment.outputs.vpc_cidr_block
  private_subnet_ids                                 = data.terraform_remote_state.forms_environment.outputs.private_subnet_ids
  ecs_cluster_arn                                    = data.terraform_remote_state.forms_environment.outputs.ecs_cluster_arn
  alb_arn_suffix                                     = data.terraform_remote_state.forms_environment.outputs.alb_arn_suffix
  alb_listener_arn                                   = data.terraform_remote_state.forms_environment.outputs.alb_main_listener_arn
  internal_alb_listener_arn                          = data.terraform_remote_state.forms_environment.outputs.internal_alb_listener_arn
  cloudfront_secret                                  = data.terraform_remote_state.forms_environment.outputs.cloudfront_secret
  send_logs_to_cyber                                 = var.send_logs_to_cyber
  submission_bounces_and_complaints_sqs_queue_name   = data.terraform_remote_state.forms_ses.outputs.submission_email_bounces_and_complaints_queue_name
  submission_deliveries_sqs_queue_name               = data.terraform_remote_state.forms_ses.outputs.submission_email_successful_deliveries_queue_name
  confirmation_bounces_and_complaints_sqs_queue_name = data.terraform_remote_state.forms_ses.outputs.confirmation_email_bounces_and_complaints_queue_name
  submission_bounces_and_complaints_kms_key_arn      = data.terraform_remote_state.forms_ses.outputs.submission_email_bounces_and_complaints_kms_key_arn
  submission_deliveries_kms_key_arn                  = data.terraform_remote_state.forms_ses.outputs.submission_email_successful_deliveries_kms_key_arn
  confirmation_bounces_and_complaints_kms_key_arn    = data.terraform_remote_state.forms_ses.outputs.confirmation_email_bounces_and_complaints_kms_key_arn
  queue_worker_capacity                              = var.forms_runner_settings.queue_worker_capacity
  disable_builtin_solidqueue_worker                  = var.forms_runner_settings.disable_builtin_solidqueue_worker
  kinesis_subscription_role_arn                      = data.terraform_remote_state.account.outputs.kinesis_subscription_role_arn
  filler_answer_email_enabled                        = var.forms_runner_settings.filler_answer_email_enabled
}
