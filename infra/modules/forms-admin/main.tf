data "aws_caller_identity" "current" {}
locals {
  sub_domain                  = "admin.${var.root_domain}"
  internal_sub_domain         = "admin.internal.${var.root_domain}"
  image                       = var.image_tag == null ? null : "${var.container_registry}/forms-admin-deploy:${var.image_tag}"
  maintenance_mode_bypass_ips = join(", ", module.common_values.vpn_ip_addresses)
  auth_credentials = {
    _ = [], # just in case we have a "null" previous auth provider
    basic_auth = [
      {
        name      = "SETTINGS__BASIC_AUTH__USERNAME",
        valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/basic-auth/username"
      },
      {
        name      = "SETTINGS__BASIC_AUTH__PASSWORD",
        valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/basic-auth/password"
      }
    ],
    auth0 = [
      {
        name      = "SETTINGS__AUTH0__CLIENT_ID",
        valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/auth0/client-id"
      },
      {
        name      = "SETTINGS__AUTH0__CLIENT_SECRET",
        valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/auth0/client-secret"
      },
      {
        name      = "SETTINGS__AUTH0__E2E_CLIENT_ID",
        valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/auth0/e2e-client-id"
      },
      {
        name      = "SETTINGS__AUTH0__E2E_CLIENT_SECRET",
        valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/auth0/e2e-client-secret"
      },
      {
        name      = "SETTINGS__AUTH0__DOMAIN",
        valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/auth0/domain"
      }
    ]
  }
  container_port = 3000

}

module "common_values" {
  source = "../common-values"
}

data "aws_iam_policy_document" "ecs_task_role_permissions" {
  statement {
    actions = [
      "cloudwatch:GetMetricStatistics"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

module "ecs_service" {
  source                           = "../ecs-service"
  env_name                         = var.env_name
  application                      = "forms-admin"
  enable_opentelemetry             = var.enable_opentelemetry
  opentelemetry_head_sampler_ratio = var.opentelemetry_head_sampler_ratio
  root_domain                      = var.root_domain
  sub_domain                       = local.sub_domain
  internal_sub_domain              = local.internal_sub_domain
  listener_priority                = 301
  include_domain_root_listener     = false
  image                            = local.image
  cpu                              = var.cpu
  memory                           = var.memory
  readonly_root_filesystem         = true
  container_port                   = local.container_port
  permit_internet_egress           = true
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
    scale_out_cooldown                          = 60
  }

  healthcheck = {
    command     = ["CMD-SHELL", "wget -O - 'http://localhost:${local.container_port}/up' || exit 1"]
    interval    = 30
    retries     = 5
    startPeriod = 180
  }

  ecs_task_role_policy_json = data.aws_iam_policy_document.ecs_task_role_permissions.json

  environment_variables = [
    {
      name  = "RACK_ENV",
      value = "production"
    },
    {
      name  = "RAILS_ENV",
      value = "production"
    },
    {
      name  = "SETTINGS__FORMS_RUNNER__URL",
      value = var.runner_base
    },
    {
      name  = "SETTINGS__AUTH_PROVIDER",
      value = var.auth_provider
    },
    {
      name  = "GOVUK_APP_DOMAIN",
      value = var.govuk_app_domain
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
      name  = "SETTINGS__FORMS_PRODUCT_PAGE__SUPPORT_URL",
      value = var.forms_product_page_support_url
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
      name  = "SETTINGS__ACT_AS_USER_ENABLED",
      value = var.act_as_user_enabled
    }
  ]

  secrets = flatten([
    {
      name      = "SETTINGS__GOVUK_NOTIFY__API_KEY",
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/notify-api-key"
    },
    {
      name      = "DATABASE_URL",
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/database/url"
    },
    {
      name      = "SETTINGS__SENTRY__DSN",
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/sentry/dsn"
    },
    {
      name      = "SECRET_KEY_BASE",
      valueFrom = "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-admin-${var.env_name}/secret-key-base"
    },
    {
      name      = "SETTINGS__MAILCHIMP__API_KEY"
      valueFrom = aws_ssm_parameter.mailchimp_api_key.arn
    },
    lookup(local.auth_credentials, var.auth_provider, []),
    lookup(local.auth_credentials, coalesce(var.previous_auth_provider, "_"), [])
  ])
}

resource "aws_lb_listener_rule" "block_api_access" {
  listener_arn = var.alb_listener_arn
  priority     = 300

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }

  condition {
    path_pattern {
      values = ["/api/*", "/api"]
    }
  }

  condition {
    host_header {
      values = [local.sub_domain]
    }
  }

}
