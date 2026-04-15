##
# When adding and editing policies for the deployer role,
# you should focus on create, update, delete, or otherwise mutating
# actions. The role has full read-only access.
##
data "aws_iam_policy_document" "forms_infra" {
  source_policy_documents = [
    data.aws_iam_policy_document.alerts.json,
    data.aws_iam_policy_document.dns.json,
    data.aws_iam_policy_document.monitoring.json,
  ]
}

data "aws_iam_policy_document" "forms_infra_1" {
  source_policy_documents = [
    data.aws_iam_policy_document.rds.json,
    data.aws_iam_policy_document.redis.json,
    data.aws_iam_policy_document.code_build_modules.json,
    data.aws_iam_policy_document.ssm.json,
    data.aws_iam_policy_document.secrets_manager.json,
  ]
}

data "aws_iam_policy_document" "forms_infra_2" {
  source_policy_documents = [
    data.aws_iam_policy_document.ses.json,
    data.aws_iam_policy_document.ecr.json,
    data.aws_iam_policy_document.eventbridge.json,
    data.aws_iam_policy_document.cloudwatch_logging.json,
    data.aws_iam_policy_document.shield.json,
    data.aws_iam_policy_document.route53.json,
    data.aws_iam_policy_document.forms_runner.json
  ]
}

data "aws_iam_policy_document" "forms_infra_3" {
  source_policy_documents = [
    data.aws_iam_policy_document.pipelines.json,
    data.aws_iam_policy_document.application_signals.json,
    data.aws_iam_policy_document.cloud_control_api.json
  ]
}

resource "aws_iam_policy" "forms_infra" {
  policy = data.aws_iam_policy_document.forms_infra.json
}

resource "aws_iam_role_policy_attachment" "forms_infra" {
  policy_arn = aws_iam_policy.forms_infra.arn
  role       = aws_iam_role.deployer.id
}

resource "aws_iam_policy" "forms_infra_1" {
  policy = data.aws_iam_policy_document.forms_infra_1.json
}

resource "aws_iam_role_policy_attachment" "forms_infra_1" {
  policy_arn = aws_iam_policy.forms_infra_1.arn
  role       = aws_iam_role.deployer.id
}

resource "aws_iam_policy" "forms_infra_2" {
  policy = data.aws_iam_policy_document.forms_infra_2.json
}

resource "aws_iam_role_policy_attachment" "forms_infra_2" {
  policy_arn = aws_iam_policy.forms_infra_2.arn
  role       = aws_iam_role.deployer.id
}

resource "aws_iam_policy" "forms_infra_3" {
  policy = data.aws_iam_policy_document.forms_infra_3.json
}

resource "aws_iam_role_policy_attachment" "forms_infra_3" {
  policy_arn = aws_iam_policy.forms_infra_3.arn
  role       = aws_iam_role.deployer.id
}

resource "aws_iam_role_policy_attachment" "full_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  role       = aws_iam_role.deployer.id
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid = "ManageKMSKeyAlerts"
    actions = [
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:TagResource",
      "kms:UpdateKeyDescription",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion"
    ]
    resources = [
      "arn:aws:kms:eu-west-2:${var.account_id}:key/*",
      "arn:aws:kms:us-east-1:${var.account_id}:key/*",
    ]
    effect = "Allow"
  }

  statement {
    sid       = "CreateKMSKeys"
    actions   = ["kms:CreateKey"]
    resources = ["*"] #CreateKey uses the * resource
    effect    = "Allow"
  }

  statement {
    sid = "CreateKMSKeyAliases"
    actions = [
      "kms:CreateAlias",
      "kms:DeleteAlias"
    ]
    resources = [
      "arn:aws:kms:eu-west-2:${var.account_id}:key/*",
      "arn:aws:kms:eu-west-2:${var.account_id}:alias/*",
      "arn:aws:kms:us-east-1:${var.account_id}:key/*",
      "arn:aws:kms:us-east-1:${var.account_id}:alias/*",
    ]
    effect = "Allow"
  }

  statement {
    sid = "ManageSNS"
    actions = [
      "sns:*Topic*",
      "sns:*Tag*",
      "sns:*Subscrib*",
      "sns:Unsubscribe",
      "sns:UntagResource",
    ]
    resources = [
      "arn:aws:sns:eu-west-2:${var.account_id}:pagerduty_integration_${var.environment_name}",
      "arn:aws:sns:eu-west-2:${var.account_id}:alert_zendesk_${var.environment_name}",
      "arn:aws:sns:eu-west-2:${var.account_id}:slo-alerts",
      "arn:aws:sns:us-east-1:${var.account_id}:cloudwatch-alarms",
    ]
    effect = "Allow"
  }

  statement {
    sid = "ManageCloudwatchMetricAlarms"
    actions = [
      "cloudwatch:*Alarm*",
      "cloudwatch:*Metric*",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = [
      "arn:aws:cloudwatch:eu-west-2:${var.account_id}:alarm:alb_healthy_host_count_*",

    ]
    effect = "Allow"
  }
}

# This relates to the `dns` root and is different from what is covered in by the permissions in the `environment` module
data "aws_iam_policy_document" "dns" {
  statement {
    sid = "ManageRoute53RecordSets"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
    ]
  }

  statement {
    sid    = "ManageInternalZoneAssociation"
    effect = "Allow"
    actions = [
      "route53:AssociateVPCWithHostedZone",
      "route53:DisassociateVPCFromHostedZone",
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${var.private_internal_zone_id}"
    ]
  }
}

data "aws_iam_policy_document" "monitoring" {
  statement {
    sid = "ManageCloudwatchDashboards"
    actions = [
      "cloudwatch:DeleteDashboards",
      "cloudwatch:PutDashboard",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = [
      "arn:aws:cloudwatch:*:${var.account_id}:dashboard/*"
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "rds" {
  statement {
    sid = "ManageRDS"
    actions = [
      "rds:*DBCluster*",
      "rds:*DBInstance*",
      "rds:*SecurityGroup*",
      "rds:*SubnetGroup*",
      "rds:*Tag*",
    ]
    resources = [
      "arn:aws:rds:eu-west-2:${var.account_id}:*"
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "redis" {
  statement {
    sid = "ManageElasticache"
    actions = [
      "elasticache:*CacheCluster*",
      "elasticache:*CacheParameter*",
      "elasticache:*CacheSubnetGroup*",
      "elasticache:*CacheSecurityGroup*",
      "elasticache:*ReplicationGroup*",
      "elasticache:*Tags*",
    ]
    resources = [
      "arn:aws:elasticache:eu-west-2:${var.account_id}:*",
    ]
  }
}

data "aws_iam_policy_document" "ses" {
  #checkov:skip=CKV_AWS_111:We use SES v1 which doesn't let us be more specific than *
  #checkov:skip=CKV_AWS_356:We use SES v1 which doesn't let us be more specific than *
  #checkov:skip=CKV_AWS_109:We have a plan to add a permissions boundary to the deployer
  statement {
    sid    = "GetUser"
    effect = "Allow"
    actions = [
      "iam:AttachUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:DetachUserPolicy",
      "iam:UntagUser",
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:user/auth0"
    ]
  }

  statement {
    sid    = "AllowManageSESTagging"
    effect = "Allow"
    actions = [
      "ses:*Tag*",
      "ses:UntagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageSESPolicies"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:policy/ses_sender"
    ]
  }

  statement {
    sid    = "ManageSESVerification"
    effect = "Allow"
    actions = [
      "ses:*Dkim*",
      "ses:*EmailAddress*",
      "ses:*Domain*",
      "ses:VerifyEmailIdentity",
      "ses:*Identity*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "ManageSESConfigurationSet"
    effect = "Allow"
    actions = [
      "ses:*ConfigurationSet*",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "ManageKMSKeySES"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:TagResource",
      "kms:UntagResource",
    ]
    resources = [
      "arn:aws:kms:eu-west-2:${var.account_id}:key/*",
    ]
  }

  statement {
    sid    = "ManageAccessKeys"
    effect = "Allow"
    actions = [
      "iam:CreateAccessKey"
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:user/auth0"
    ]
  }

  statement {
    sid    = "ManageSQS"
    effect = "Allow"
    actions = [
      "sqs:*queue*"
    ]
    resources = [
      "arn:aws:sqs:eu-west-2:${var.account_id}:*"
    ]
  }

  statement {
    sid = "ManageSNS"
    actions = [
      "sns:*Topic*",
      "sns:*Tag*",
      "sns:*Subscrib*",
      "sns:Unsubscribe",
      "sns:UntagResource",
    ]
    resources = [
      "arn:aws:sns:eu-west-2:${var.account_id}:ses_bounces_and_complaints", # TODO: remove me once all envs use the new queues
      "arn:aws:sns:eu-west-2:${var.account_id}:auth0_ses_bounces_and_complaints",
      "arn:aws:sns:eu-west-2:${var.account_id}:submission_email_ses_bounces_and_complaints",
      "arn:aws:sns:eu-west-2:${var.account_id}:submission_email_ses_successful_deliveries",
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "code_build_modules" {
  # These are needed for:
  # code-build-build
  # code-build-run-docker-build
  # code-build-run-smoke-tests
  statement {
    sid    = "ManageLogs"
    effect = "Allow"
    actions = [
      "logs:*LogEvents",
      "logs:*LogStream",
      "logs:*SubscriptionFilters",
      "logs:*SubscriptionFilter",
      "logs:*LogGroup",
    ]
    resources = [
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/codebuild/*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:codebuild/*"
    ]
  }
  statement {
    sid    = "ManageCodebuild"
    effect = "Allow"
    actions = [
      "codebuild:*Project*",
      "codebuild:*Build*",
    ]
    resources = [
      "arn:aws:codebuild:eu-west-2:${var.account_id}:project/*"
    ]
  }
  statement {
    sid    = "ManageRoles"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeletePolicyVersion",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:DeleteRole",
      "iam:PassRole",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:TagRole"
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:policy/codebuild-*",
      "arn:aws:iam::${var.account_id}:role/codebuild-*",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-event-bridge-*",
      "arn:aws:iam::${var.account_id}:role/event-bridge-actor",
      "arn:aws:iam::${var.account_id}:role/deployer-${var.environment_name}"
    ]
  }
  statement {
    sid    = "ManagePolicies"
    effect = "Allow"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:TagPolicy"
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:policy/codebuild-*",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-event-bridge-*",
    ]
  }
}

data "aws_iam_policy_document" "pipelines" {
  statement {
    actions = [
      "codestar-connections:UseConnection",
      "codestar-connections:PassConnection"
    ]
    resources = [var.codestar_connection_arn]
    effect    = "Allow"
  }

  statement {
    actions   = ["codecommit:GitPull"]
    resources = [var.codestar_connection_arn]
    effect    = "Allow"
  }

  statement {
    sid       = "ManageArtifactBuckets"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::pipeline-*", "arn:aws:s3:::pipeline-*/*"]
  }

  statement {
    sid     = "ManageLambdaBuckets"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::govuk-forms-*-pipeline-invoker",
      "arn:aws:s3:::govuk-forms-*-pipeline-invoker/*",

      "arn:aws:s3:::govuk-forms-*-paused-pipeline-detection",
      "arn:aws:s3:::govuk-forms-*-paused-pipeline-detection/*",

      "arn:aws:s3:::govuk-forms-*-paused-pipeline-detection-access-logs",
      "arn:aws:s3:::govuk-forms-*-paused-pipeline-detection-access-logs/*",

      "arn:aws:s3:::govuk-forms-*-pipeline-invoker-access-logs",
      "arn:aws:s3:::govuk-forms-*-pipeline-invoker-access-logs/*",
    ]
  }

  statement {
    sid     = "ManageFormsRunnerBuckets"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::govuk-forms-${var.environment_name}-file-upload*",
    ]
  }

  statement {
    sid     = "ManageStateBucketAccessLogs"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::gds-forms-${var.environment_type}-tfstate-access-logs",
      "arn:aws:s3:::gds-forms-${var.environment_type}-tfstate-access-logs/*",
    ]
  }

  statement {
    sid     = "ManageALBAccessLogsAccessLogs"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::*-alb-access-logs-access-logs",
      "arn:aws:s3:::*-alb-access-logs-access-logs/*",
    ]
  }

  statement {
    sid    = "ManageMalwareProtectionRoleforS3"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UpdateRole",
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:role/malware-protection-for-s3"
    ]
  }

  statement {
    sid    = "ManageMalwareProtectionPoliciesforS3"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:policy/allow-malware-scanning-for-s3"
    ]
  }

  statement {
    sid    = "ManageMalwareProtectionPlan"
    effect = "Allow"
    actions = [
      "guardduty:CreateMalwareProtectionPlan",
      "guardduty:DeleteMalwareProtectionPlan",
      "guardduty:GetMalwareProtectionPlan",
      "guardduty:TagResource",
      "guardduty:UntagResource",
      "guardduty:UpdateMalwareProtectionPlan",
    ]
    resources = [
      "arn:aws:guardduty:eu-west-2:${var.account_id}:malware-protection-plan/*"
    ]
  }

  statement {
    sid    = "ManageLambdaFunctions"
    effect = "Allow"
    actions = [
      "lambda:*Function",
      "lambda:*Permission",
      "lambda:PutFunctionConcurrency",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
    ]

    resources = [
      "arn:aws:lambda:*:${var.account_id}:function:*",
    ]
  }

  statement {
    sid    = "ManagePipelines"
    effect = "Allow"
    actions = [
      "codepipeline:CreatePipeline",
      "codepipeline:DeletePipeline",
      "codepipeline:UpdatePipeline",
      "codepipeline:TagResource",
      "codepipeline:UntagResource",
    ]

    resources = [
      "arn:aws:codepipeline:eu-west-2:${var.account_id}:*"
    ]
  }

  statement {
    sid    = "ManageRelatedIAMRoles"
    effect = "Allow"
    actions = [
      "iam:*Role",
      "iam:*RolePolicy",
    ]

    resources = [
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-lambda-pipeline-invoker",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-lambda-paused-pipeline-invoker"
    ]
  }

  statement {
    sid    = "ManageLogs"
    effect = "Allow"
    actions = [
      "logs:*LogEvents",
      "logs:*LogStream",
      "logs:*SubscriptionFilters",
      "logs:*SubscriptionFilter",
      "logs:*LogGroup",
    ]
    resources = [
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/lambda/*",
    ]
  }
}

data "aws_iam_policy_document" "ecr" {
  statement {
    actions = [
      "ecr:*"
    ]
    resources = [
      "arn:aws:ecr:eu-west-2:${var.deploy_account_id}:*",
    ]
    effect = "Allow"
  }

  statement {
    # CodePipeline appears to perform GetAuthorizationToken
    # with resource "*", and a statement with an ARN
    # like "arn:aws:ecr::ACCT_ID:*" is insufficient to grant
    # it permission
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "eventbridge" {
  #checkov:skip=CKV_AWS_356: resource "*" is restricted to events actions
  #checkov:skip=CKV_AWS_111: there are many event resources the deployer
  #                          role will write to, and adding conditions for
  #                          each will add a lot to an already constrained
  #                          character count
  statement {
    sid    = "AllowEventActions"
    effect = "Allow"
    actions = [
      "events:*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AllowPassRoleForEventBridge"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::*:role/*"]

    condition {
      variable = "iam:PassedToService"
      test     = "StringLike"
      values   = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudwatch_logging" {
  statement {
    actions = [
      "logs:PutRetentionPolicy",
      "logs:DeleteLogGroup",
      "logs:DeleteRetentionPolicy",
      "logs:DeleteSubscriptionFilter",
    ]
    resources = [
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:*",
      "arn:aws:logs:us-east-1:${var.account_id}:log-group:*",
    ]
    effect = "Allow"
  }

  statement {
    sid = "ManageSubscriptionFilterForCRIBL"
    actions = [
      "logs:*SubscriptionFilter"
    ]
    resources = [
      "arn:aws:logs:*:${var.deploy_account_id}:destination:kinesis-log-destination",
      "arn:aws:logs:*:${var.deploy_account_id}:destination:kinesis-log-destination-us-east-1",
      "arn:aws:logs:*:${var.account_id}:log-group:*:log-stream:*",
    ]
  }
}

data "aws_iam_policy_document" "shield" {
  statement {
    sid = "ShieldPermissionsProtectionResources"
    actions = [
      "shield:*HealthCheck",
      "shield:*Protection",
      "shield:TagResource",
      "shield:UntagResource",
    ]
    resources = [
      "arn:aws:shield::${var.account_id}:protection/*",
    ]
    effect = "Allow"
  }

  statement {
    sid = "ShieldPermissionsProtectionGroupResources"
    actions = [
      "shield:*ProtectionGroup",
      "shield:ListProtectionGroups",
      "shield:ListResourcesInProtectionGroup",
      "shield:TagResource",
      "shield:UntagResource",

    ]
    resources = [
      "arn:aws:shield::${var.account_id}:protection-group/*",
    ]
    effect = "Allow"
  }

  statement {
    sid = "ShieldPermissionsAllResources"
    actions = [
      "shield:*DRTLogBucket",
      "shield:*DRTRole",
      "shield:AssociateProactiveEngagementDetails",
      "shield:CreateProtection",
      "shield:EnableApplicationLayerAutomaticResponse",
      "shield:EnableProactiveEngagement",
      "shield:DisableApplicationLayerAutomaticResponse",
      "shield:DisableProactiveEngagement",
      "shield:UpdateEmergencyContactSettings",
    ]
    resources = [
      "*",
    ]
    effect = "Allow"
  }

  statement {
    sid = "ShieldPermissionsIAM"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateServiceLinkedRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UpdateRole",
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:role/shield-response-team",
      "arn:aws:iam::${var.account_id}:role/aws-service-role/shield.amazonaws.com/AWSServiceRoleForAWSShield"
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "route53" {
  statement {
    sid = "CreateRoute53HealthChecks"
    actions = [
      "route53:CreateHealthCheck"
    ]
    resources = ["*"] # CreateHealthCheck uses *
    effect    = "Allow"
  }

  statement {
    sid = "ConfigureRoute53HealthChecks"
    actions = [
      "route53:ChangeTagsForResource",
      "route53:DeleteHealthCheck",
      "route53:UpdateHealthCheck"
    ]
    resources = [
      "arn:aws:cloudwatch:eu-west-2:${var.account_id}:${var.environment_name}_cloudfront_total_error_rate",
      "arn:aws:cloudwatch:us-east-1:${var.account_id}:ddos_detected_in_${var.environment_name}",
      "arn:aws:route53:::healthcheck/*"
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "ssm" {
  statement {
    sid = "DescribeSSMParameters"
    actions = [
      "ssm:DescribeParameters",
    ]
    resources = [
      "arn:aws:ssm:eu-west-2:${var.account_id}:*"
    ]
    effect = "Allow"
  }

  statement {
    sid = "ManageSSMParameters"
    actions = [
      "ssm:*Tag*",
      "ssm:*Parameter*",
    ]
    resources = [
      "arn:aws:ssm:eu-west-2:${var.account_id}:parameter/*",
    ]
    effect = "Allow"
  }

  # We allow all operations except deleting a parameter. If you need the deployer role to delete a parameter then you can temporarily comment out this block.
  statement {
    sid = "DeleteSSMParameters"
    actions = [
      "ssm:DeleteParameter",
    ]
    resources = [
      "arn:aws:ssm:eu-west-2:${var.account_id}:parameter/*",
    ]
    effect = "Deny"
  }
}

data "aws_iam_policy_document" "forms_runner" {
  statement {
    sid = "ManageRunnerSpecificRoles"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateServiceLinkedRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
    ]

    resources = [
      "arn:aws:iam::${var.account_id}:role/govuk-forms-submissions-to-s3-${var.environment_name}",
      "arn:aws:iam::${var.account_id}:role/govuk-s3-end-to-end-test-${var.environment_name}",
    ]
  }
}

data "aws_iam_policy_document" "application_signals" {
  statement {
    sid    = "ManageApplicationSignalsSLOs"
    effect = "Allow"
    actions = [
      "application-signals:BatchUpdateExclusionWindows",
      "application-signals:CreateServiceLevelObjective",
      "application-signals:UpdateServiceLevelObjective",
      "application-signals:DeleteServiceLevelObjective",
      "application-signals:ListServiceLevelObjectiveExclusionWindows",
      "application-signals:TagResource",
      "application-signals:UntagResource"
    ]
    resources = ["arn:aws:application-signals:eu-west-2:${var.account_id}:slo/*"]
  }

  statement {
    sid    = "CloudWatchApplicationSignalsCreateServiceLinkedRolePermissions"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["arn:aws:iam::${var.account_id}:role/aws-service-role/application-signals.cloudwatch.amazonaws.com/AWSServiceRoleForCloudWatchApplicationSignals"]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["application-signals.cloudwatch.amazonaws.com"]
    }
  }

  statement {
    sid    = "CloudWatchApplicationSignalsPutMetricAlarmPermissions"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm"
    ]
    resources = [
      "arn:aws:cloudwatch:eu-west-2:${var.account_id}:alarm:SLO-AttainmentGoalAlarm-*",
      "arn:aws:cloudwatch:eu-west-2:${var.account_id}:alarm:SLO-WarningAlarm-*",
      "arn:aws:cloudwatch:eu-west-2:${var.account_id}:alarm:SLI-HealthAlarm-*"
    ]
  }
}

data "aws_iam_policy_document" "cloud_control_api" {
  # These permissions are required for the `awscc` provider to create, update, delete, and list
  # Cloud Control API resources, which includes the Application Signals SLO resources.
  # See: https://docs.aws.amazon.com/cloudcontrolapi/latest/userguide/security.html

  # It seems super scary to give `cloudformation:*` permissions, but the Cloud Control API
  # is implemented as a layer on top of CloudFormation, and the `awscc` provider
  # needs these permissions to manage resources. These permissions are essentially saying
  # 'allow the deployer to use the Cloud Control API to attempt to CRUDL any resource'
  # The deployer role will still be limited by the other permissions it has, so it won't be able
  # to create resources we haven't explicitly given it permission for.
  # eg. if we removed `s3:CreateBucket` from the deployer role, it wouldn't be able to create S3 buckets,
  # even though it has `cloudformation:CreateResource` permission.
  statement {
    sid    = "CloudControlAPIActions"
    effect = "Allow"
    actions = [
      "cloudformation:CreateResource",
      "cloudformation:GetResource",
      "cloudformation:UpdateResource",
      "cloudformation:DeleteResource",
      "cloudformation:ListResources",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "secrets_manager" {
  statement {
    sid = "ManageSecretsManagerSecrets"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:eu-west-2:${var.account_id}:secret:data-api/${var.environment_name}/*",
    ]
    effect = "Allow"
  }
}
