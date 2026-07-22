data "aws_caller_identity" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
}

resource "aws_sesv2_email_identity" "from_address" {
  email_identity = var.from_address

  # Default configuration set name.
  # It can be overridden when sending mail.
  #
  # Default is Auth0 set because Auth0 sends via
  # SMTP and does not set the required headers.
  configuration_set_name = aws_sesv2_configuration_set.auth0.configuration_set_name
}

##
# SES v2 configuration
##
resource "aws_sesv2_account_suppression_attributes" "account_suppression_list" {
  suppressed_reasons = ["COMPLAINT", "BOUNCE"]
}

resource "aws_sesv2_configuration_set" "auth0" {
  configuration_set_name = "${var.environment_name}_auth0"

  reputation_options {
    reputation_metrics_enabled = true
  }

  delivery_options {
    tls_policy = "REQUIRE"
  }
}

resource "aws_sesv2_configuration_set_event_destination" "auth0" {
  configuration_set_name = aws_sesv2_configuration_set.auth0.configuration_set_name
  event_destination_name = "auth0_bounces_and_complaints"

  event_destination {
    enabled              = true
    matching_event_types = ["BOUNCE", "COMPLAINT", "REJECT"]

    sns_destination {
      topic_arn = module.auth0_bounces_and_complaints_sqs.aws_sns_topic
    }
  }
}

resource "aws_sesv2_configuration_set" "form_submissions" {
  configuration_set_name = "${var.environment_name}_form_submissions"

  reputation_options {
    reputation_metrics_enabled = true
  }

  delivery_options {
    tls_policy = "REQUIRE"
  }

  suppression_options {
    suppressed_reasons = [] # We don't want to use the suppression list for form submission emails
  }
}

resource "aws_sesv2_configuration_set_event_destination" "form_submissions_bounces_and_complaints" {
  configuration_set_name = aws_sesv2_configuration_set.form_submissions.configuration_set_name
  event_destination_name = "form_submissions_bounces_and_complaints"

  event_destination {
    enabled              = true
    matching_event_types = ["BOUNCE", "COMPLAINT", "REJECT"]

    sns_destination {
      topic_arn = module.submission_email_bounces_and_complaints_sqs.aws_sns_topic
    }
  }
}

resource "aws_sesv2_configuration_set_event_destination" "form_submissions_successful_deliveries" {
  configuration_set_name = aws_sesv2_configuration_set.form_submissions.configuration_set_name
  event_destination_name = "form_submissions_successful_deliveries"

  event_destination {
    enabled              = true
    matching_event_types = ["DELIVERY"]

    sns_destination {
      topic_arn = module.submission_email_successful_deliveries_sqs.aws_sns_topic
    }
  }
}

resource "aws_sesv2_configuration_set_event_destination" "form_submissions_delivery_tls_versions" {
  configuration_set_name = aws_sesv2_configuration_set.form_submissions.configuration_set_name
  event_destination_name = "form_submissions_delivery_tls_versions"

  event_destination {
    enabled              = true
    matching_event_types = ["DELIVERY"]

    cloud_watch_destination {
      dimension_configuration {
        default_dimension_value = aws_sesv2_configuration_set.form_submissions.configuration_set_name
        dimension_name          = "ses:configuration-set"
        dimension_value_source  = "MESSAGE_TAG"
      }

      dimension_configuration {
        default_dimension_value = "unknown"
        dimension_name          = "ses:outgoing-tls-version"
        dimension_value_source  = "MESSAGE_TAG"
      }
    }
  }
}

resource "aws_sesv2_configuration_set" "form_confirmations" {
  configuration_set_name = "${var.environment_name}_form_confirmations"

  reputation_options {
    reputation_metrics_enabled = true
  }
}

resource "aws_sesv2_configuration_set_event_destination" "form_confirmations_bounces_and_complaints" {
  configuration_set_name = aws_sesv2_configuration_set.form_confirmations.configuration_set_name
  event_destination_name = "form_confirmations_bounces_and_complaints"

  event_destination {
    enabled              = true
    matching_event_types = ["BOUNCE", "COMPLAINT", "REJECT"]

    sns_destination {
      topic_arn = module.confirmation_email_bounces_and_complaints_sqs.aws_sns_topic
    }
  }
}

##
# SES v1 configuration
#
# We use v2 preferentially, but testing shows that this amount of
# v1 configuration is needed for bounce, complaint, and rejection
# reporting when sending via SMTP (which is done by Auth0)
##
resource "aws_ses_event_destination" "failed_email_notification" {
  name                   = "failed_email_notification"
  configuration_set_name = aws_ses_configuration_set.bounces_and_complaints_handling_rule.name
  enabled                = true
  matching_types         = ["bounce", "complaint", "reject"]

  sns_destination {
    topic_arn = module.auth0_bounces_and_complaints_sqs.aws_sns_topic
  }
}

resource "aws_ses_configuration_set" "bounces_and_complaints_handling_rule" {
  #checkov:skip=CKV_AWS_365 We'll look at this later
  name = "bounces_and_complaints_handling_rule"

  reputation_metrics_enabled = true
}
