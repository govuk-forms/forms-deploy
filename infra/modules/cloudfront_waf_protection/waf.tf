resource "aws_wafv2_ip_set" "system_egress_ips" {
  provider = aws.us-east-1

  name               = "${var.environment_name}-system-egress-ips"
  description        = "Egress IPs for ${var.environment_name} environment"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"

  addresses = [for ip in var.nat_gateway_egress_ips : "${ip}/32"]
}

resource "aws_wafv2_ip_set" "rate_limit_bypass_cidrs" {
  provider = aws.us-east-1

  name               = "${var.environment_name}-rate-limit-bypass-cidrs"
  description        = "List of CIDR blocks we allow to bypass rate limiting rules. This is used to allow the penetration testers to carry out tests that would otherwise get them rate limited."
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"

  addresses = var.rate_limit_bypass_cidrs
}

resource "aws_wafv2_ip_set" "ips_to_block" {
  provider = aws.us-east-1

  name               = "${var.environment_name}-ips-to-block"
  description        = "Origin IPs to block for ${var.environment_name} environment"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"

  addresses = var.ips_to_block
}

resource "aws_wafv2_regex_pattern_set" "admin_extended_post_pages" {
  provider = aws.us-east-1

  name        = "${var.environment_name}-admin-extended-post-pages"
  description = "Regex patterns for admin pages that require extended POST body size limits"
  scope       = "CLOUDFRONT"

  regular_expression {
    regex_string = "^/forms/\\d+/pages/(?:new|\\d+/edit)/guidance-preview$"
  }

  regular_expression {
    regex_string = "^/forms/\\d+/welsh-translation$"
  }
}

resource "aws_wafv2_rule_group" "admin_body_size_limits" {
  provider = aws.us-east-1

  name        = "${var.environment_name}-admin-body-size-limits"
  description = "Rule group for admin request body size restrictions"
  scope       = "CLOUDFRONT"
  capacity    = 50

  rule {
    # Allow large POSTs when uploading multiple options in bulk (form creation)
    name     = "allow_bulk_options_uploads"
    priority = 1

    action {
      allow {}
      # Stop processing
    }

    statement {
      and_statement {
        statement {
          regex_match_statement {
            field_to_match {
              uri_path {}
            }
            regex_string = "^/forms/\\d+/pages/(?:new|\\d+/edit)/selection/bulk-options$"
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }

        statement {
          size_constraint_statement {
            field_to_match {
              body {}
            }
            comparison_operator = "LE"
            size                = var.bulk_options_max_size
            text_transformation {
              priority = 1
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BulkOptionsUploads"
      sampled_requests_enabled   = false
    }
  }

  rule {
    # Allow larger POST bodies for admin endpoints that require extended payload sizes
    name     = "allow_admin_extended_post_bodies"
    priority = 2

    action {
      allow {}
      # Stop processing
    }

    statement {
      and_statement {
        statement {
          regex_pattern_set_reference_statement {
            arn = aws_wafv2_regex_pattern_set.admin_extended_post_pages.arn
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          size_constraint_statement {
            field_to_match {
              body {}
            }
            comparison_operator = "LE"
            size                = var.admin_extended_post_body_max_size
            text_transformation {
              priority = 1
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AdminExtendedPostBodies"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "AdminBodySizeLimitsRuleGroup"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_rule_group" "public_form_body_size_limits" {
  provider = aws.us-east-1

  name        = "${var.environment_name}-public-form-body-size-limits"
  description = "Rule group for public form request body size restrictions"
  scope       = "CLOUDFRONT"
  capacity    = 50

  rule {
    # Allow file uploads when filling out a form
    name     = "allow_file_uploads"
    priority = 1

    action {
      allow {}
      # Stop processing
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            field_to_match {
              single_header {
                name = "content-type"
              }
            }
            positional_constraint = "STARTS_WITH"
            search_string         = "multipart/form-data"
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          regex_match_statement {
            field_to_match {
              uri_path {}
            }
            # /:mode/:form_id/:form_slug(.locale)/:page_slug
            regex_string = "^/(?:preview-draft|preview-archived|preview-live|form)/\\d+/[\\w-]+(\\.(cy|en))?/[a-zA-Z\\d]+$"
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          size_constraint_statement {
            field_to_match {
              body {}
            }
            comparison_operator = "LE"
            size                = var.file_upload_max_size
            text_transformation {
              priority = 1
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "FileUploads"
      sampled_requests_enabled   = false
    }
  }

  rule {
    # Enforce standard maximum size for form response bodies
    # ie. POST requests to standard form fields (text inputs, selections, etc.)
    name     = "allow_standard_form_responses"
    priority = 2

    action {
      allow {}
      # Stop processing
    }

    statement {
      and_statement {
        statement {
          regex_match_statement {
            field_to_match {
              uri_path {}
            }
            # /:mode/:form_id/:form_slug(.locale)/:page_slug(/:answer_index)
            regex_string = "^/(?:preview-draft|preview-archived|preview-live|form)/\\d+/[\\w-]+(\\.(cy|en))?/[a-zA-Z\\d]+(?:/\\d+)?$"
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          size_constraint_statement {
            field_to_match {
              body {}
            }
            comparison_operator = "LE"
            size                = var.standard_form_response_body_max_size
            text_transformation {
              priority = 1
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "StandardFormResponses"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "PublicFormBodySizeLimitsRuleGroup"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl" "this" {
  #checkov:skip=CKV_AWS_192:We don't use log4j
  provider = aws.us-east-1

  name        = "cloudfront_waf_${var.environment_name}"
  description = "AWS WAF for the CloudFront Distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "OriginIPRateLimit"
    sampled_requests_enabled   = false
  }

  lifecycle {
    create_before_destroy = true
  }

  rule {
    name     = "allow_egress_ips_of_${var.environment_name}_env"
    priority = 10

    action {
      allow {}
      # Stop processing
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.system_egress_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment_name}_env_system_ips_allowed"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AdminBodySizeLimitsRuleGroup"
    priority = 2

    override_action {
      none {}
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.admin_body_size_limits.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AdminBodySizeLimitsRuleGroup"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "PublicFormBodySizeLimitsRuleGroup"
    priority = 3

    override_action {
      none {}
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.public_form_body_size_limits.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "PublicFormBodySizeLimitsRuleGroup"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"

        rule_action_override {
          action_to_use {
            block {}
          }

          name = "AWSManagedIPDDoSList"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 6
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAntiDDoSRuleSet"
    priority = 15

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
    name     = "OriginIPRateLimit"
    priority = 100

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.ip_rate_limit
        aggregate_key_type = "IP"

        scope_down_statement {
          not_statement {
            statement {
              ip_set_reference_statement {
                arn = aws_wafv2_ip_set.rate_limit_bypass_cidrs.arn
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "OriginIPRateLimit"
      sampled_requests_enabled   = false
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
        arn = aws_wafv2_ip_set.ips_to_block.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment_name}_ips_blocked"
      sampled_requests_enabled   = false
    }

  }
}

resource "aws_cloudwatch_log_group" "waf" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  provider          = aws.us-east-1
  name              = "aws-waf-logs-${var.environment_name}"
  retention_in_days = 30
}

module "cribl_well_known" {
  source = "../well-known/cribl"
}


resource "aws_cloudwatch_log_subscription_filter" "waf" {
  provider = aws.us-east-1

  name = "via-cribl-to-splunk"

  log_group_name = aws_cloudwatch_log_group.waf.name

  filter_pattern  = ""
  destination_arn = module.cribl_well_known.kinesis_destination_arns["us-east-1"]
  distribution    = "ByLogStream"
  role_arn        = var.kinesis_subscription_role_arn
}


resource "aws_wafv2_web_acl_logging_configuration" "this" {
  provider                = aws.us-east-1
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

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
