locals {
  cloudfront_arn = data.terraform_remote_state.forms_environment.outputs.cloudfront_arn
}

resource "aws_shield_protection" "cloudfront" {
  name         = "cloudfront"
  resource_arn = local.cloudfront_arn
}

resource "aws_iam_role" "shield_response_team" {

  name = "shield-response-team"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "ShieldResponseTeamAssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "drt.shield.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "shield_response_team" {
  role       = aws_iam_role.shield_response_team.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSShieldDRTAccessPolicy"
}

resource "aws_shield_drt_access_role_arn_association" "shield_response_team" {
  role_arn = aws_iam_role.shield_response_team.arn
}

resource "aws_shield_drt_access_log_bucket_association" "alb_log_access" {
  log_bucket              = data.aws_s3_bucket.logs_bucket.bucket
  role_arn_association_id = aws_shield_drt_access_role_arn_association.shield_response_team.id
}

resource "aws_iam_role_policy" "alb_log_access" {

  name = "shield_response_team_alb_log_access"
  role = aws_iam_role.shield_response_team.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${data.aws_s3_bucket.logs_bucket.bucket}",
          "arn:aws:s3:::${data.aws_s3_bucket.logs_bucket.bucket}/*"
        ],
        Sid = "AWSDDoSResponseTeamAccessS3Bucket"
      }
    ]
  })
}

resource "aws_shield_protection_group" "protected_resources" {
  depends_on = [aws_shield_protection.cloudfront]

  protection_group_id = "Incoming-Traffic-Resources"
  aggregation         = "MAX"
  pattern             = "ARBITRARY"
  members = [
    local.cloudfront_arn,
    data.aws_lb.forms_lb.arn
  ]
}

resource "aws_ssm_parameter" "pagerduty_email" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  name  = "/account/pagerduty-email"
  type  = "SecureString"
  value = "dummy-email-address@digital.cabinet-office.gov.uk"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "aws_ssm_parameter" "pagerduty_phone_number" {
  #checkov:skip=CKV_AWS_337:The parameter is already using the default key

  name  = "/account/pagerduty-phone-number"
  type  = "SecureString"
  value = "+1234567890"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}


resource "aws_shield_proactive_engagement" "escalation_contacts" {
  enabled = true

  emergency_contact {
    contact_notes = "GOV.UK Forms Infrastructure Team"
    email_address = data.aws_ssm_parameter.pagerduty_email.value
    phone_number  = data.aws_ssm_parameter.pagerduty_phone_number.value
  }

  depends_on = [aws_shield_drt_access_role_arn_association.shield_response_team]
}


resource "aws_route53_health_check" "admin" {
  count = var.environmental_settings.enable_shield_advanced_healthchecks ? 1 : 0

  failure_threshold = "3"
  fqdn              = "admin.${var.root_domain}"
  port              = 443
  request_interval  = "30"
  resource_path     = "/up"
  type              = "HTTPS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_health_check" "product_page" {
  count = var.environmental_settings.enable_shield_advanced_healthchecks ? 1 : 0

  failure_threshold = "3"
  fqdn              = "product-page.${var.root_domain}"
  port              = 443
  request_interval  = "30"
  resource_path     = "/up"
  type              = "HTTPS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_health_check" "runner" {
  count = var.environmental_settings.enable_shield_advanced_healthchecks ? 1 : 0

  failure_threshold = "3"
  fqdn              = "submit.${var.root_domain}"
  port              = 443
  request_interval  = "30"
  resource_path     = "/up"
  type              = "HTTPS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_total_error_rate" {
  provider            = aws.us-east-1
  alarm_name          = "${var.environment_name}_cloudfront_total_error_rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "TotalErrorRate"
  namespace           = "AWS/Cloudfront"
  period              = 60
  statistic           = "Average"
  threshold           = 100
  treat_missing_data  = "notBreaching"
  actions_enabled     = true
  alarm_actions       = [data.terraform_remote_state.forms_environment.outputs.zendesk_alert_us_east_1_topic_arn]
  ok_actions          = [data.terraform_remote_state.forms_environment.outputs.zendesk_alert_us_east_1_topic_arn]

  dimensions = {
    DistributionId = local.cloudfront_arn
  }
}

resource "aws_route53_health_check" "cloudfront_total_error_rate" {
  count = var.environmental_settings.enable_shield_advanced_healthchecks ? 1 : 0

  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.cloudfront_total_error_rate.alarm_name
  cloudwatch_alarm_region         = "us-east-1"
  insufficient_data_health_status = "Healthy"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "ddos_detection" {
  provider            = aws.us-east-1
  alarm_name          = "ddos_detected_in_${var.environment_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DDoSDetected"
  namespace           = "AWS/DDoSProtection"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  actions_enabled = true
  alarm_actions   = [data.terraform_remote_state.forms_environment.outputs.zendesk_alert_us_east_1_topic_arn]
  ok_actions      = [data.terraform_remote_state.forms_environment.outputs.zendesk_alert_us_east_1_topic_arn]
}

resource "aws_route53_health_check" "ddos_detection" {
  count = var.environmental_settings.enable_shield_advanced_healthchecks ? 1 : 0

  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.ddos_detection.alarm_name
  cloudwatch_alarm_region         = "us-east-1"
  insufficient_data_health_status = "Healthy"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_health_check" "healthy_hosts" {
  for_each = module.alerts.healthy_host_count_alarm_names

  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = each.value
  cloudwatch_alarm_region         = "eu-west-2"
  insufficient_data_health_status = "Healthy"
}

resource "aws_route53_health_check" "aggregated" {
  count = var.environmental_settings.enable_shield_advanced_healthchecks ? 1 : 0

  type                   = "CALCULATED"
  child_health_threshold = 4
  child_healthchecks = concat([
    aws_route53_health_check.admin[0].id,
    aws_route53_health_check.product_page[0].id,
    aws_route53_health_check.runner[0].id,
    aws_route53_health_check.cloudfront_total_error_rate[0].id,
    aws_route53_health_check.ddos_detection[0].id
  ], [for _, alarm in aws_route53_health_check.healthy_hosts : alarm.id])
}

resource "aws_shield_protection_health_check_association" "system_health" {
  count = var.environmental_settings.enable_shield_advanced_healthchecks ? 1 : 0

  health_check_arn     = aws_route53_health_check.aggregated[0].arn
  shield_protection_id = aws_shield_protection.cloudfront.id
}

resource "aws_iam_service_linked_role" "shield" {
  aws_service_name = "shield.amazonaws.com"
  description      = "AWSServiceRoleForAWSShield IAM role"
}
