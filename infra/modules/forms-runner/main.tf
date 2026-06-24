data "aws_caller_identity" "current" {}

locals {
  image                       = var.image_tag == null ? null : "${var.container_repository}:${var.image_tag}"
  maintenance_mode_bypass_ips = join(", ", module.common_values.vpn_ip_addresses)
  container_port              = 3000
}

module "common_values" {
  source = "../common-values"
}

module "users" {
  source = "../users"
}

data "aws_iam_policy_document" "ecs_task_role_permissions" {
  statement {
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
    effect    = "Allow"
    condition {
      test     = "StringLike"
      variable = "cloudwatch:namespace"

      values = [
        "Forms*"
      ]
    }
  }

  statement {
    sid = "FileUploadKMS"

    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey"
    ]
    resources = [
      "arn:aws:kms:eu-west-2:${data.aws_caller_identity.current.account_id}:alias/file-upload-${var.env_name}",
    ]
  }

  statement {
    sid = "SESPermissions"

    effect  = "Allow"
    actions = ["ses:SendRawEmail"]
    resources = [
      "arn:aws:ses:eu-west-2:${data.aws_caller_identity.current.account_id}:identity/*",
      "arn:aws:ses:eu-west-2:${data.aws_caller_identity.current.account_id}:configuration-set/*"
    ]
  }


  statement {
    sid = "SQSPermissions"

    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:ReceiveMessage"
    ]
    resources = [
      "arn:aws:sqs:eu-west-2:${data.aws_caller_identity.current.account_id}:${var.submission_bounces_and_complaints_sqs_queue_name}",
      "arn:aws:sqs:eu-west-2:${data.aws_caller_identity.current.account_id}:${var.submission_deliveries_sqs_queue_name}",
      "arn:aws:sqs:eu-west-2:${data.aws_caller_identity.current.account_id}:${var.confirmation_bounces_and_complaints_sqs_queue_name}"
    ]
  }

  statement {
    sid = "AllowSQSMessageDecryption"

    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      var.submission_bounces_and_complaints_kms_key_arn,
      var.submission_deliveries_kms_key_arn,
      var.confirmation_bounces_and_complaints_kms_key_arn,
    ]
  }
}

module "ecs_service" {
  source                           = "../ecs-service"
  env_name                         = var.env_name
  application                      = "forms-runner"
  enable_opentelemetry             = var.enable_opentelemetry
  opentelemetry_head_sampler_ratio = var.opentelemetry_head_sampler_ratio
  root_domain                      = var.root_domain
  sub_domain                       = "submit.${var.root_domain}"
  internal_sub_domain              = "submit.internal.${var.root_domain}"
  listener_priority                = 100
  include_domain_root_listener     = false
  image                            = local.image
  cpu                              = var.cpu
  memory                           = var.memory
  readonly_root_filesystem         = false
  container_port                   = local.container_port
  permit_internet_egress           = true
  permit_redis_egress              = true
  permit_postgres_egress           = true
  vpc_id                           = var.vpc_id
  vpc_cidr_block                   = var.vpc_cidr_block
  private_subnet_ids               = var.private_subnet_ids
  alb_arn_suffix                   = var.alb_arn_suffix
  alb_listener_arn                 = var.alb_listener_arn
  internal_alb_listener_arn        = var.internal_alb_listener_arn
  ecs_cluster_arn                  = var.ecs_cluster_arn
  cloudfront_secret                = var.cloudfront_secret

  kinesis_subscription_role_arn = var.kinesis_subscription_role_arn

  scaling_rules = {
    min_capacity                                = var.min_capacity
    max_capacity                                = var.max_capacity
    p95_response_time_scaling_threshold_seconds = 1
    scale_in_cooldown                           = 180
    scale_out_cooldown                          = 45
  }

  healthcheck = {
    command     = ["CMD-SHELL", "wget -O - 'http://localhost:${local.container_port}/up' || exit 1"]
    interval    = 30
    retries     = 5
    startPeriod = 180
  }

  ecs_task_role_policy_json     = data.aws_iam_policy_document.ecs_task_role_permissions.json
  additional_task_role_assumers = var.additional_forms_runner_role_assumers

  environment_variables = [
    {
      name  = "REDIS_URL",
      value = "rediss://${var.elasticache_primary_endpoint_address}:${var.elasticache_port}"
    },
    {
      name  = "SETTINGS__FORMS_API__BASE_URL",
      value = var.api_base_url
    },
    {
      name  = "SETTINGS__FORMS_ADMIN__BASE_URL",
      value = var.admin_base_url
    },
    {
      name  = "SETTINGS__FORMS_PRODUCT_PAGE__BASE_URL",
      value = var.product_page_base_url
    },
    {
      name  = "RACK_ENV",
      value = "production"
    },
    {
      name  = "RAILS_ENV",
      value = "production"
    },
    {
      name  = "RAILS_MAX_THREADS",
      value = var.rails_max_threads
    },
    {
      name  = "SENTRY_ENVIRONMENT",
      value = "aws-${var.env_name}"
    },
    {
      name  = "SETTINGS__SENTRY__ENVIRONMENT",
      value = "aws-${var.env_name}"
    },
    {
      name  = "SETTINGS__MAINTENANCE_MODE__ENABLED",
      value = var.enable_maintenance_mode
    },
    {
      name  = "SETTINGS__MAINTENANCE_MODE__BYPASS_IPS",
      value = local.maintenance_mode_bypass_ips
    },
    {
      name  = "SETTINGS__FORMS_ENV",
      value = var.env_name
    },
    {
      name  = "SETTINGS__CLOUDWATCH_METRICS_ENABLED",
      value = var.cloudwatch_metrics_enabled
    },
    {
      name  = "SETTINGS__ANALYTICS_ENABLED",
      value = var.analytics_enabled
    },
    {
      name  = "SETTINGS__COPY_OF_ANSWERS_ENABLED",
      value = var.copy_of_answers_enabled
    },
    {
      name  = "SETTINGS__AWS__S3_SUBMISSION_IAM_ROLE_ARN",
      value = aws_iam_role.submissions_to_s3_role.arn
    },
    {
      name  = "SETTINGS__AWS__FILE_UPLOAD_S3_BUCKET_NAME",
      value = module.file_upload_bucket.name
    },
    {
      name  = "SETTINGS__AWS__SES_SUBMISSION_EMAIL_CONFIGURATION_SET_NAME",
      value = var.ses_submissions_configuration_set_name
    },
    {
      name  = "SETTINGS__AWS__SES_CONFIRMATION_EMAIL_CONFIGURATION_SET_NAME",
      value = var.ses_confirmations_configuration_set_name
    },
    {
      name  = "SETTINGS__AWS__SUBMISSION_EMAIL_BOUNCES_AND_COMPLAINTS_SQS_QUEUE_NAME",
      value = var.submission_bounces_and_complaints_sqs_queue_name
    },
    {
      name  = "SETTINGS__AWS__SUBMISSION_EMAIL_DELIVERIES_SQS_QUEUE_NAME",
      value = var.submission_deliveries_sqs_queue_name
    },
    {
      name  = "SETTINGS__AWS__CONFIRMATION_EMAIL_BOUNCES_AND_COMPLAINTS_SQS_QUEUE_NAME",
      value = var.confirmation_bounces_and_complaints_sqs_queue_name
    },
    {
      name  = "SETTINGS__SES_SUBMISSION_EMAIL__FROM_EMAIL_ADDRESS",
      value = var.ses_submission_email_from_email_address
    },
    {
      name  = "SETTINGS__SES_SUBMISSION_EMAIL__REPLY_TO_EMAIL_ADDRESS",
      value = var.ses_submission_email_reply_to_email_address
    },
    {
      name  = "SETTINGS__GOVUK_ONE_LOGIN__BASE_URL",
      value = var.govuk_one_login_base_url
    },
    {
      name  = "KMS_KEY_ID",
      value = aws_kms_alias.active_record_alias.name
    },
    {
      name  = "DISABLE_SOLID_QUEUE",
      value = tostring(var.disable_builtin_solidqueue_worker)
    },
  ]

  secrets = [
    {
      name      = "SETTINGS__GOVUK_NOTIFY__API_KEY",
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/notify-api-key"
    },
    {
      name      = "SETTINGS__SENTRY__DSN",
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/sentry/dsn"
    },
    {
      name      = "SECRET_KEY_BASE",
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/secret-key-base"
    },
    {
      name      = "DATABASE_URL",
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/database/url"
    },
    {
      name      = "QUEUE_DATABASE_URL",
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-queue-${var.env_name}/database/url"
    },
    {
      name      = "SETTINGS__SUBMISSION_STATUS_API__SECRET"
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/submission_status_api_shared_secret"
    },
    {
      name      = "SETTINGS__GOVUK_ONE_LOGIN__CLIENT_ID"
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/govuk-one-login/client-id"
    },
    {
      name      = "SETTINGS__GOVUK_ONE_LOGIN__PRIVATE_KEY"
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.env_name}/govuk-one-login/private-key"
    }
  ]
}
