resource "aws_wafv2_ip_set" "ips_to_block_alb" {
  name               = "${var.environment_name}-ips-to-block-alb"
  description        = "Origin IPs to block for alb in ${var.environment_name} environment"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"

  addresses = var.ips_to_block
}

resource "aws_wafv2_web_acl" "alb" {
  #checkov:skip=CKV_AWS_192:We don't use log4j

  name        = "alb_${var.environment_name}"
  description = "AWS WAF for the load balancer"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "OriginIPBlock"
    sampled_requests_enabled   = false
  }

  rule {
    name     = "AWS-AWSManagedRulesAntiDDoSRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAntiDDoSRuleSet"
        vendor_name = "AWS"

        managed_rule_group_configs {
          aws_managed_rules_anti_ddos_rule_set {
            sensitivity_to_block = "LOW"

            client_side_action_config {
              challenge {
                usage_of_action = "ENABLED"
                sensitivity     = "HIGH"

                dynamic "exempt_uri_regular_expression" {
                  for_each = var.anti_ddos_exempt_uri_regular_expressions
                  content {
                    regex_string = exempt_uri_regular_expression.value
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAntiDDoSRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "OriginIPBlock"
    priority = 110

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.ips_to_block_alb.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment_name}_ips_blocked_alb"
      sampled_requests_enabled   = false
    }

  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}

resource "aws_cloudwatch_log_group" "waf_alb_log_group" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  name              = "aws-waf-logs-alb-${var.environment_name}"
  retention_in_days = 30
}

module "cribl_well_known" {
  source = "../well-known/cribl"
}

resource "aws_cloudwatch_log_subscription_filter" "via_cribl_to_splunk" {
  name = "via-cribl-to-splunk"

  log_group_name = aws_cloudwatch_log_group.waf_alb_log_group.name

  filter_pattern  = ""
  destination_arn = module.cribl_well_known.kinesis_destination_arns["eu-west-2"]
  distribution    = "ByLogStream"
  role_arn        = var.kinesis_subscription_role_arn
}


resource "aws_wafv2_web_acl_logging_configuration" "this" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_alb_log_group.arn]
  resource_arn            = aws_wafv2_web_acl.alb.arn

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
      condition {
        action_condition {
          action = "COUNT"
        }
      }
    }
  }
}
