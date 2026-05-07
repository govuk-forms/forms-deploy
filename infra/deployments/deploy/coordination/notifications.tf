module "chatbot_well_known" {
  source = "../../../modules/well-known/chatbot"
}

locals {
  chatbot_message_input_paths = {
    pipeline = "$.detail.pipeline"
    account  = "$.account"
    time     = "$.time"
  }

  # Excludes integration account from the list of all account ids
  # This is because we don't want to build Slack notification resources
  # for the integration account (yet).
  account_except_integration = {
    for account in setsubtract(keys(module.other_accounts.all_accounts_id), ["integration"]) :
    account => module.other_accounts.all_accounts_id[account]
  }
}

resource "aws_sns_topic" "alerts_topic" {
  # checkov:skip=CKV_AWS_26:AWS ChatBot doesn't configure it with encryption
  name            = module.chatbot_well_known.alerts_topic_name
  delivery_policy = <<JSON
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
}
JSON
}

resource "aws_sns_topic_policy" "alerts_topic_access_policy" {
  arn = aws_sns_topic.alerts_topic.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowPublishFromServices",
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.alerts_topic.arn
        Principal = {
          Service = [
            "cloudwatch.amazonaws.com",
            "events.amazonaws.com",
            "codestar-notifications.amazonaws.com"
          ]
        }
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = concat(
              [module.other_accounts.deploy_account_id],
              [for _, id in module.other_accounts.environment_accounts_id : id]
            )
          }
        }
      },
      {
        Sid      = "AllowPublishFromAccounts"
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.alerts_topic.arn
        Principal = {
          AWS = concat(
            ["arn:aws:iam::${module.other_accounts.deploy_account_id}:root"],
            [for _, id in module.other_accounts.environment_accounts_id : "arn:aws:iam::${id}:root"]
          )
        }
      }
    ]
  })
}

resource "aws_sns_topic" "deployments_topic" {
  # checkov:skip=CKV_AWS_26:AWS ChatBot doesn't configure it with encryption
  name            = module.chatbot_well_known.deployments_topic_name
  delivery_policy = <<JSON
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
}
JSON
}

resource "aws_sns_topic" "infra_notifications_topic" {
  # checkov:skip=CKV_AWS_26:AWS ChatBot doesn't configure it with encryption
  name            = module.chatbot_well_known.infra_notifications_topic_name
  delivery_policy = <<JSON
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
}
JSON
}

resource "aws_sns_topic_policy" "infra_notifications_topic_access_policy" {
  arn = aws_sns_topic.infra_notifications_topic.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowPublishFromServices",
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.infra_notifications_topic.arn
        Principal = {
          Service = [
            "cloudwatch.amazonaws.com",
            "events.amazonaws.com",
            "codestar-notifications.amazonaws.com"
          ]
        }
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = [
              module.other_accounts.deploy_account_id,
              module.other_accounts.integration_account_id
            ]
          }
        }
      },
      {
        Sid      = "AllowPublishFromDeployAndIntegrationAccounts"
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.infra_notifications_topic.arn
        Principal = {
          AWS = [
            "arn:aws:iam::${module.other_accounts.deploy_account_id}:root",
            "arn:aws:iam::${module.other_accounts.integration_account_id}:root"
          ]
        }
      }
    ]
  })
}

resource "aws_sns_topic_policy" "deployments_topic_access_policy" {
  arn = aws_sns_topic.deployments_topic.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowPublishFromServices",
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.deployments_topic.arn
        Principal = {
          Service = [
            "cloudwatch.amazonaws.com",
            "events.amazonaws.com",
            "codestar-notifications.amazonaws.com"
          ]
        }
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = concat(
              [module.other_accounts.deploy_account_id],
              [for _, id in module.other_accounts.environment_accounts_id : id]
            )
          }
        }
      },
      {
        Sid      = "AllowPublishFromAccounts"
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.deployments_topic.arn
        Principal = {
          AWS = concat(
            ["arn:aws:iam::${module.other_accounts.deploy_account_id}:root"],
            [for _, id in module.other_accounts.environment_accounts_id : "arn:aws:iam::${id}:root"]
          )
        }
      }
    ]
  })
}

module "slack_notifications" {
  for_each = local.account_except_integration
  source   = "./slack-notifications"


  account_id                      = each.value
  account_name                    = each.key
  dead_letter_queue_arn           = aws_sqs_queue.event_bridge_dlq.arn
  pipeline_completion_topic_arn   = aws_sns_topic.deployments_topic.arn
  pipeline_failure_topic_arn      = each.key == "development" ? aws_sns_topic.deployments_topic.arn : aws_sns_topic.alerts_topic.arn
  run_e2e_tests_failure_topic_arn = each.key == "development" ? aws_sns_topic.deployments_topic.arn : aws_sns_topic.alerts_topic.arn
}
