##
# When adding and editing policies for the deployer role,
# you should focus on create, update, delete, or otherwise mutating
# actions. The role has full read-only access.
##
data "aws_iam_policy_document" "forms_infra" {
  source_policy_documents = [
    data.aws_iam_policy_document.acm.json,
    data.aws_iam_policy_document.application-autoscaling.json,
    data.aws_iam_policy_document.application-signals.json,
    data.aws_iam_policy_document.cloudformation.json,
    data.aws_iam_policy_document.cloudfront.json,
    data.aws_iam_policy_document.cloudwatch.json,
    data.aws_iam_policy_document.code.json, # codebuild, codecommit, codepipeline, codestar-connections
  ]
}

data "aws_iam_policy_document" "forms_infra_1" {
  source_policy_documents = [
    data.aws_iam_policy_document.ec2.json,
    data.aws_iam_policy_document.ecr.json,
    data.aws_iam_policy_document.ecs.json,
    data.aws_iam_policy_document.elasticache.json,
    data.aws_iam_policy_document.events.json,
    data.aws_iam_policy_document.guardduty.json,
  ]
}

data "aws_iam_policy_document" "forms_infra_2" {
  source_policy_documents = [
    data.aws_iam_policy_document.kms.json,
    data.aws_iam_policy_document.lambda.json,
    data.aws_iam_policy_document.logs.json,
    data.aws_iam_policy_document.rds.json,
    data.aws_iam_policy_document.route53.json,
    data.aws_iam_policy_document.s3.json,
  ]
}

data "aws_iam_policy_document" "forms_infra_3" {
  source_policy_documents = [
    data.aws_iam_policy_document.secretsmanager.json,
    data.aws_iam_policy_document.ses.json,
    data.aws_iam_policy_document.shield.json,
    data.aws_iam_policy_document.sns.json,
    data.aws_iam_policy_document.sqs.json,
    data.aws_iam_policy_document.ssm.json,
    data.aws_iam_policy_document.wafv2.json,
  ]
}

resource "aws_iam_role_policy_attachment" "iam" {
  policy_arn = aws_iam_policy.iam.arn
  role       = aws_iam_role.deployer.id
}

resource "aws_iam_policy" "iam" {
  policy = data.aws_iam_policy_document.iam.json
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

data "aws_iam_policy_document" "acm" {
  statement {
    actions = [
      "acm:*Certificate*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:acm:eu-west-2:${var.account_id}:certificate/*",
      "arn:aws:acm:us-east-1:${var.account_id}:certificate/*"
    ]
    sid = "ManageCertificates"
  }
}

data "aws_iam_policy_document" "application-autoscaling" {
  #checkov:skip=CKV_AWS_111: allow write access without constraint when needed
  #checkov:skip=CKV_AWS_356: allow resource * when needed
  statement {
    actions = [
      "application-autoscaling:*"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "ManageApplicationAutoScaling"
  }
}

data "aws_iam_policy_document" "application-signals" {
  statement {
    actions = [
      "application-signals:BatchUpdateExclusionWindows",
      "application-signals:CreateServiceLevelObjective",
      "application-signals:UpdateServiceLevelObjective",
      "application-signals:DeleteServiceLevelObjective",
      "application-signals:TagResource",
      "application-signals:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:application-signals:eu-west-2:${var.account_id}:slo/*"
    ]
    sid = "ManageApplicationSignalsSLOs"
  }
}

data "aws_iam_policy_document" "cloudformation" {
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
    actions = [
      "cloudformation:CreateResource",
      "cloudformation:UpdateResource",
      "cloudformation:DeleteResource"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "CloudControlAPIActions"
  }
}

data "aws_iam_policy_document" "cloudfront" {
  statement {
    actions = [
      "cloudfront:AssociateAlias",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:*Distribution*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:cloudfront::${var.account_id}:distribution/*"
    ]
    sid = "ManageCloudfrontDistribution"
  }
}

data "aws_iam_policy_document" "cloudwatch" {
  statement {
    actions = [
      "cloudwatch:*Alarm*",
      "cloudwatch:*Metric*",
      "cloudwatch:*Tag*",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:cloudwatch:eu-west-2:${var.account_id}:*",
      "arn:aws:cloudwatch:us-east-1:${var.account_id}:*"
    ]
    sid = "ManageCloudWatchAlarms"
  }

  statement {
    actions = [
      "cloudwatch:DeleteDashboards",
      "cloudwatch:PutDashboard",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:cloudwatch:*:${var.account_id}:dashboard/*"
    ]
    sid = "ManageCloudwatchDashboards"
  }

}

data "aws_iam_policy_document" "code" {
  statement {
    actions = [
      "codebuild:*Project*",
      "codebuild:*Build*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:codebuild:eu-west-2:${var.account_id}:project/*"
    ]
    sid = "ManageCodebuild"
  }

  statement {
    actions = [
      "codecommit:GitPull"
    ]
    effect = "Allow"
    resources = [
      "${var.codestar_connection_arn}"
    ]
  }

  statement {
    actions = [
      "codepipeline:CreatePipeline",
      "codepipeline:DeletePipeline",
      "codepipeline:UpdatePipeline",
      "codepipeline:TagResource",
      "codepipeline:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:codepipeline:eu-west-2:${var.account_id}:*"
    ]
    sid = "ManagePipelines"
  }

  statement {
    actions = [
      "codestar-connections:UseConnection",
      "codestar-connections:PassConnection"
    ]
    effect = "Allow"
    resources = [
      "${var.codestar_connection_arn}"
    ]
  }
}

data "aws_iam_policy_document" "ec2" {
  statement {
    actions = [
      "ec2:*SecurityGroup*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ec2:eu-west-2:${var.account_id}:*/*"
    ]
    sid = "ManageSecurityGroups"
  }

  statement {
    actions = [
      "ec2:*TransitGatewayRouteTable"
    ]
    effect = "Deny"
    resources = [
      "arn:aws:ec2:eu-west-2:${var.account_id}:*"
    ]
    sid = "DenyTransitGateway"
  }

  statement {
    actions = [
      "ec2:CreateTags",
      "ec2:*VpcEndpoint*",
      "ec2:*SecurityGroup*",
      "ec2:*NatGateway*",
      "ec2:*Address",
      "ec2:*Subnet*",
      "ec2:*RouteTable",
      "ec2:*RouteTableAssociation",
      "ec2:*Vpc",
      "ec2:*InternetGateway*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ec2:eu-west-2:${var.account_id}:*"
    ]
    sid = "ManageNetwork"
  }
}

data "aws_iam_policy_document" "ecr" {
  statement {
    actions = [
      "ecr:*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ecr:eu-west-2:${var.deploy_account_id}:*"
    ]
  }

  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
}

data "aws_iam_policy_document" "ecs" {
  #checkov:skip=CKV_AWS_111: allow write access without constraint when needed
  #checkov:skip=CKV_AWS_356: allow resource * when needed
  statement {
    actions = [
      "ecs:*Cluster",
      "ecs:*Service",
      "ecs:TagResource",
      "ecs:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ecs:eu-west-2:${var.account_id}:*"
    ]
    sid = "ManageECSClustersAndServices"
  }

  statement {
    actions = [
      "ecs:*TaskDefinition",
      "ecs:*TaskSet",
      "ecs:RunTask"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "ManageEcsTaskDefinitions"
  }
}

data "aws_iam_policy_document" "elasticache" {
  statement {
    actions = [
      "elasticache:*CacheCluster*",
      "elasticache:*CacheParameter*",
      "elasticache:*CacheSubnetGroup*",
      "elasticache:*CacheSecurityGroup*",
      "elasticache:*ReplicationGroup*",
      "elasticache:*Tags*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:elasticache:eu-west-2:${var.account_id}:*"
    ]
    sid = "ManageElasticache"
  }

  statement {
    actions = [
      "elasticloadbalancing:*Tags",
      "elasticloadbalancing:*TargetGroup*",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:*Listener",
      "elasticloadbalancing:*Rule*",
      "elasticloadbalancing:*LoadBalancer*",
      "elasticloadbalancing:SetWebACL"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:elasticloadbalancing:eu-west-2:${var.account_id}:*"
    ]
    sid = "ManageAlb"
  }
}

data "aws_iam_policy_document" "events" {
  #checkov:skip=CKV_AWS_356: resource "*" is restricted to events actions
  #checkov:skip=CKV_AWS_111: there are many event resources the deployer
  #                          role will write to, and adding conditions for
  #                          each will add a lot to an already constrained
  #                          character count
  statement {
    actions = [
      "events:*"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "AllowEventActions"
  }
}

data "aws_iam_policy_document" "guardduty" {
  statement {
    actions = [
      "guardduty:CreateMalwareProtectionPlan",
      "guardduty:DeleteMalwareProtectionPlan",
      "guardduty:TagResource",
      "guardduty:UntagResource",
      "guardduty:UpdateMalwareProtectionPlan"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:guardduty:eu-west-2:${var.account_id}:malware-protection-plan/*"
    ]
    sid = "ManageMalwareProtectionPlan"
  }
}
data "aws_iam_policy_document" "iam" {

  statement {
    actions = [
      "iam:*Policy",
      "iam:*PolicyVersion",
      "iam:*PolicyVersions",
      "iam:*RolePolicy",
      "iam:*AssumeRolePolicy"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-admin-ecs-task-execution-additional",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-runner-ecs-task-execution-additional",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-product-page-ecs-task-execution-additional",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-runner-queue-worker-ecs-task-execution-additional",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-admin-ecs-task-policy",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-admin-adot-collector",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-runner-ecs-task-policy",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-runner-adot-collector",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-product-page-ecs-task-policy",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-forms-product-page-adot-collector"
    ]
    sid = "ManageEcsPolicies"
  }

  statement {
    actions = [
      "iam:*Role",
      "iam:*RolePolicy"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-lambda-pipeline-invoker",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-lambda-paused-pipeline-invoker"
    ]
    sid = "ManageRelatedIAMRoles"
  }

  statement {
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeletePolicyVersion",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:DeleteRole",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole"
    ]
    condition {
      variable = "iam:PermissionsBoundary"
      test     = "StringEquals"
      values   = [aws_iam_policy.permissions_boundary.arn]
    }
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:policy/codebuild-*",
      "arn:aws:iam::${var.account_id}:role/codebuild-*",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-event-bridge-*",
      "arn:aws:iam::${var.account_id}:role/event-bridge-actor",
      "arn:aws:iam::${var.account_id}:role/deployer-${var.environment_name}",
      "arn:aws:iam::${var.account_id}:role/malware-protection-for-s3"
    ]
    sid = "ManageRoles"
  }

  statement {
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole"
    ]
    condition {
      variable = "iam:PermissionsBoundary"
      test     = "StringEquals"
      values   = [aws_iam_policy.permissions_boundary.arn]
    }
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-forms-admin-ecs-task",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-forms-runner-ecs-task",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-forms-product-page-ecs-task",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-forms-admin-ecs-task-execution",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-forms-runner-ecs-task-execution",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-forms-product-page-ecs-task-execution",
      "arn:aws:iam::${var.account_id}:role/${var.environment_name}-forms-runner-queue-worker-ecs-task-execution"
    ]
    sid = "ManageTaskAndTaskExecutionRoles"
  }

  statement {
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateServiceLinkedRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UpdateRole"
    ]
    condition {
      variable = "iam:PermissionsBoundary"
      test     = "StringEquals"
      values   = [aws_iam_policy.permissions_boundary.arn]
    }
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:role/shield-response-team",
      "arn:aws:iam::${var.account_id}:role/aws-service-role/shield.amazonaws.com/AWSServiceRoleForAWSShield"
    ]
    sid = "ShieldPermissionsIAM"
  }

  statement {
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateServiceLinkedRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole"
    ]
    condition {
      variable = "iam:PermissionsBoundary"
      test     = "StringEquals"
      values   = [aws_iam_policy.permissions_boundary.arn]
    }
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:role/govuk-forms-submissions-to-s3-${var.environment_name}",
      "arn:aws:iam::${var.account_id}:role/govuk-s3-end-to-end-test-${var.environment_name}"
    ]
    sid = "ManageRunnerSpecificRoles"
  }

  statement {
    actions = [
      "iam:AttachUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:DetachUserPolicy",
      "iam:UntagUser"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:user/auth0"
    ]
    sid = "GetUser"
  }

  statement {
    actions = [
      "iam:CreateAccessKey"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:user/auth0"
    ]
    sid = "ManageAccessKeys"
  }

  statement {
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:policy/allow-malware-scanning-for-s3",
      "arn:aws:iam::${var.account_id}:policy/ses_sender",
      "arn:aws:iam::${var.account_id}:policy/codebuild-*",
      "arn:aws:iam::${var.account_id}:policy/${var.environment_name}-event-bridge-*"
    ]
    sid = "ManageMalwareProtectionPoliciesforS3"
  }

  statement {
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    condition {
      test     = "StringLike"
      values   = ["application-signals.cloudwatch.amazonaws.com"]
      variable = "iam:AWSServiceName"
    }
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:role/aws-service-role/application-signals.cloudwatch.amazonaws.com/AWSServiceRoleForCloudWatchApplicationSignals"
    ]
    sid = "CloudWatchApplicationSignalsCreateServiceLinkedRolePermissions"
  }

  statement {
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    condition {
      test     = "StringLike"
      values   = ["wafv2.amazonaws.com"]
      variable = "iam:AWSServiceName"
    }
    effect = "Allow"
    resources = [
      "arn:aws:iam::${var.account_id}:role/*"
    ]
    sid = "CreateServiceLinkedRoleForWAF"
  }

  statement {
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    condition {
      test     = "StringLike"
      values   = ["ecs.application-autoscaling.amazonaws.com"]
      variable = "iam:AWSServiceName"
    }
    effect = "Allow"
    resources = [
      "arn:aws:iam::*:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"
    ]
    sid = "ManageServiceLinkedRoleForAutoscaling"
  }

  statement {
    actions = [
      "iam:PassRole"
    ]
    condition {
      test     = "StringLike"
      values   = ["events.amazonaws.com"]
      variable = "iam:PassedToService"
    }
    effect = "Allow"
    resources = [
      "arn:aws:iam::*:role/*"
    ]
    sid = "AllowPassRoleForEventBridge"
  }

  statement {
    actions = [
      "iam:PassRole"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:iam::*:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"
    ]
    sid = "AllowPassingServiceLinkedRole"
  }

}

data "aws_iam_policy_document" "kms" {

  statement {
    actions = [
      "kms:CreateAlias",
      "kms:DeleteAlias"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:kms:eu-west-2:${var.account_id}:key/*",
      "arn:aws:kms:eu-west-2:${var.account_id}:alias/*",
      "arn:aws:kms:us-east-1:${var.account_id}:key/*",
      "arn:aws:kms:us-east-1:${var.account_id}:alias/*"
    ]
    sid = "CreateKMSKeyAliases"
  }


  statement {
    actions = [
      "kms:CreateKey"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "CreateKMSKeys"
  }

  statement {
    actions = [
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:TagResource",
      "kms:UpdateKeyDescription",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:kms:eu-west-2:${var.account_id}:key/*",
      "arn:aws:kms:us-east-1:${var.account_id}:key/*"
    ]
    sid = "ManageKMSKeys"
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = [
      "lambda:*Function",
      "lambda:*Permission",
      "lambda:PutFunctionConcurrency",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:lambda:*:${var.account_id}:function:*"
    ]
    sid = "ManageLambdaFunctions"
  }
}

data "aws_iam_policy_document" "logs" {
  #checkov:skip=CKV_AWS_356: allow resource * when needed
  statement {
    actions = [
      "logs:*LogEvents",
      "logs:*LogStream",
      "logs:*SubscriptionFilters",
      "logs:*SubscriptionFilter",
      "logs:*LogGroup"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/codebuild/*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:codebuild/*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/lambda/*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/ecs/forms-admin-${var.environment_name}:*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/ecs/forms-admin-${var.environment_name}/adot-collector:*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/ecs/forms-runner-${var.environment_name}:*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/ecs/forms-runner-${var.environment_name}/adot-collector:*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/ecs/forms-runner-queue-worker-${var.environment_name}:*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/ecs/forms-runner-queue-worker-${var.environment_name}/adot-collector:*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/ecs/forms-product-page-${var.environment_name}:*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:/aws/ecs/forms-product-page-${var.environment_name}/adot-collector:*",
      "arn:aws:logs:us-east-1:${var.account_id}:log-group:aws-waf-logs-${var.environment_name}*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:aws-waf-logs-alb-${var.environment_name}*"
    ]
    sid = "ManageLogs"
  }

  statement {
    actions = [
      "logs:*SubscriptionFilter"
    ]
    resources = [
      "arn:aws:logs:*:${var.deploy_account_id}:destination:kinesis-log-destination",
      "arn:aws:logs:*:${var.deploy_account_id}:destination:kinesis-log-destination-us-east-1",
      "arn:aws:logs:*:${var.account_id}:log-group:*:log-stream:*"
    ]
    effect = "Allow"
    sid    = "ManageSubscriptionFilterForCRIBL"
  }

  statement {
    actions = [
      "logs:*LogDelivery",
      "logs:PutResourcePolicy",
      "logs:TagResource"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "ManageCloudwatchLogs"
  }

  statement {
    actions = [
      "logs:PutRetentionPolicy",
      "logs:DeleteLogGroup",
      "logs:DeleteRetentionPolicy",
      "logs:DeleteSubscriptionFilter"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:*",
      "arn:aws:logs:us-east-1:${var.account_id}:log-group:*"
    ]
  }
}

data "aws_iam_policy_document" "rds" {

  statement {
    actions = [
      "rds:*DBCluster*",
      "rds:*DBInstance*",
      "rds:*SecurityGroup*",
      "rds:*SubnetGroup*",
      "rds:*Tag*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:rds:eu-west-2:${var.account_id}:*"
    ]
    sid = "ManageRDS"
  }
}

data "aws_iam_policy_document" "route53" {
  statement {
    actions = [
      "route53:AssociateVPCWithHostedZone",
      "route53:DisassociateVPCFromHostedZone"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:route53:::hostedzone/${var.private_internal_zone_id}"
    ]
    sid = "ManageInternalZoneAssociation"
  }

  statement {
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:route53:::hostedzone/${var.hosted_zone_id}",
      "arn:aws:route53:::hostedzone/${var.private_internal_zone_id}"
    ]
    sid = "ManageRoute53RecordSets"
  }

  statement {
    actions = [
      "route53:ChangeTagsForResource",
      "route53:DeleteHealthCheck",
      "route53:UpdateHealthCheck"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:cloudwatch:eu-west-2:${var.account_id}:${var.environment_name}_cloudfront_total_error_rate",
      "arn:aws:cloudwatch:us-east-1:${var.account_id}:ddos_detected_in_${var.environment_name}",
      "arn:aws:route53:::healthcheck/*"
    ]
    sid = "ConfigureRoute53HealthChecks"
  }

  statement {
    actions = [
      "route53:CreateHealthCheck"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "CreateRoute53HealthChecks"
  }

}

data "aws_iam_policy_document" "s3" {
  statement {
    actions = [
      "s3:*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::pipeline-*",
      "arn:aws:s3:::pipeline-*/*",

      "arn:aws:s3:::govuk-forms-*-pipeline-invoker",
      "arn:aws:s3:::govuk-forms-*-pipeline-invoker/*",
      "arn:aws:s3:::govuk-forms-*-paused-pipeline-detection",
      "arn:aws:s3:::govuk-forms-*-paused-pipeline-detection/*",
      "arn:aws:s3:::govuk-forms-*-paused-pipeline-detection-access-logs",
      "arn:aws:s3:::govuk-forms-*-paused-pipeline-detection-access-logs/*",
      "arn:aws:s3:::govuk-forms-*-pipeline-invoker-access-logs",
      "arn:aws:s3:::govuk-forms-*-pipeline-invoker-access-logs/*",

      "arn:aws:s3:::govuk-forms-${var.environment_name}-file-upload*",

      "arn:aws:s3:::gds-forms-${var.environment_type}-tfstate-access-logs",
      "arn:aws:s3:::gds-forms-${var.environment_type}-tfstate-access-logs/*",

      "arn:aws:s3:::*-alb-access-logs-access-logs",
      "arn:aws:s3:::*-alb-access-logs-access-logs/*",
      "arn:aws:s3:::govuk-forms-alb-logs-${var.environment_name}*",

      "arn:aws:s3:::govuk-forms-${var.environment_name}-error-page*"
    ]
    sid = "ManageS3"
  }

  statement {
    actions = [
      "s3:DeleteObject"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::gds-forms-${var.environment_type}-tfstate/*.tflock"
    ]
    sid = "ReleaseTerraformStateLock"
  }

  statement {
    actions = [
      "s3:PutObject",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::gds-forms-${var.environment_type}-tfstate/*",
      "arn:aws:s3:::gds-forms-${var.environment_type}-tfstate"
    ]
    sid = "ManageTerraformStateBuckets"
  }
}

data "aws_iam_policy_document" "secretsmanager" {
  statement {
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:GetSecretValue"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:secretsmanager:eu-west-2:${var.account_id}:secret:data-api/${var.environment_name}/*",
      "arn:aws:secretsmanager:eu-west-2:${var.account_id}:secret:rds-db-credentials/cluster-*"
    ]
    sid = "ManageRdsDbCredentialSecrets"
  }
}

data "aws_iam_policy_document" "ses" {
  #checkov:skip=CKV_AWS_111:We use SES v1 which doesn't let us be more specific than *
  #checkov:skip=CKV_AWS_356:We use SES v1 which doesn't let us be more specific than *
  #checkov:skip=CKV_AWS_109:We have a plan to add a permissions boundary to the deployer
  statement {
    actions = [
      "ses:*ConfigurationSet*"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "ManageSESConfigurationSet"
  }

  statement {
    actions = [
      "ses:*Dkim*",
      "ses:*EmailAddress*",
      "ses:*Domain*",
      "ses:VerifyEmailIdentity",
      "ses:*Identity*",
      "ses:*Tag*",
      "ses:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "ManageSESVerification"
  }
}

data "aws_iam_policy_document" "shield" {
  statement {
    actions = [
      "shield:*DRTLogBucket",
      "shield:*DRTRole",
      "shield:AssociateProactiveEngagementDetails",
      "shield:CreateProtection",
      "shield:EnableApplicationLayerAutomaticResponse",
      "shield:EnableProactiveEngagement",
      "shield:DisableApplicationLayerAutomaticResponse",
      "shield:DisableProactiveEngagement",
      "shield:UpdateEmergencyContactSettings"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
    sid = "ShieldPermissionsAllResources"
  }

  statement {
    actions = [
      "shield:*HealthCheck",
      "shield:*Protection",
      "shield:TagResource",
      "shield:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:shield::${var.account_id}:protection/*"
    ]
    sid = "ShieldPermissionsProtectionResources"
  }

  statement {
    actions = [
      "shield:*ProtectionGroup",
      "shield:TagResource",
      "shield:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:shield::${var.account_id}:protection-group/*"
    ]
    sid = "ShieldPermissionsProtectionGroupResources"
  }
}

data "aws_iam_policy_document" "sns" {
  statement {
    actions = [
      "sns:*Topic*",
      "sns:*Tag*",
      "sns:*Subscrib*",
      "sns:Unsubscribe",
      "sns:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:sns:eu-west-2:${var.account_id}:pagerduty_integration_${var.environment_name}",
      "arn:aws:sns:eu-west-2:${var.account_id}:alert_zendesk_${var.environment_name}",
      "arn:aws:sns:eu-west-2:${var.account_id}:slo-alerts",
      "arn:aws:sns:us-east-1:${var.account_id}:cloudwatch-alarms",
      "arn:aws:sns:eu-west-2:${var.account_id}:ses_bounces_and_complaints", # TODO: remove me once all envs use the new queues https://trello.com/c/BCDU9U7N/3456-remove-sesbouncesandcomplaints-sns-resource-if-all-environments-are-using-the-new-queues
      "arn:aws:sns:eu-west-2:${var.account_id}:auth0_ses_bounces_and_complaints",
      "arn:aws:sns:eu-west-2:${var.account_id}:submission_email_ses_bounces_and_complaints",
      "arn:aws:sns:eu-west-2:${var.account_id}:submission_email_ses_successful_deliveries"
    ]
    sid = "ManageSNS"
  }
}

data "aws_iam_policy_document" "sqs" {
  statement {
    actions = [
      "sqs:*queue*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:sqs:eu-west-2:${var.account_id}:*"
    ]
    sid = "ManageSQS"
  }
}

data "aws_iam_policy_document" "ssm" {
  statement {
    actions = [
      "ssm:*Tag*",
      "ssm:*Parameter*"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ssm:eu-west-2:${var.account_id}:parameter/*"
    ]
    sid = "ManageSSMParameters"
  }
  # We allow all operations except deleting a parameter. If you need the deployer role to delete a parameter then you can temporarily comment out this block.


  statement {
    actions = [
      "ssm:DeleteParameter"
    ]
    effect = "Deny"
    resources = [
      "arn:aws:ssm:eu-west-2:${var.account_id}:parameter/*"
    ]
    sid = "DeleteSSMParameters"
  }

  statement {
    actions = [
      "ssm:DescribeParameters"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ssm:eu-west-2:${var.account_id}:*"
    ]
    sid = "DescribeSSMParameters"
  }

}

data "aws_iam_policy_document" "wafv2" {
  statement {
    actions = [
      "wafv2:*LoggingConfiguration",
      "wafv2:CreateWebACL",
      "wafv2:DeleteWebACL",
      "wafv2:UpdateWebACL"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:wafv2:us-east-1:${var.account_id}:regional/webacl/*",
      "arn:aws:wafv2:eu-west-2:${var.account_id}:regional/webacl/*"
    ]
    sid = "ManageWebACL"
  }

  statement {
    actions = [
      "wafv2:*WebACL",
      "wafv2:*LoggingConfiguration",
      "wafv2:TagResource",
      "wafv2:UntagResource",
      "wafv2:*RuleGroup",
      "wafv2:*RegexPatternSet"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/webacl/cloudfront_waf_${var.environment_name}/*",
      "arn:aws:wafv2:eu-west-2:${var.account_id}:regional/webacl/alb_${var.environment_name}/*",
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/rulegroup/${var.environment_name}-*/*",
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/regexpatternset/${var.environment_name}-*",
      "arn:aws:wafv2:us-east-1:153427709519:global/rulegroup/ShieldMitigationRuleGroup_*"
    ]
    sid = "ManageWAFv2WebACL"
  }

  statement {
    actions = [
      "wafv2:CreateWebACL",
      "wafv2:PutManagedRuleSetVersions",
      "wafv2:UpdateWebACL"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/managedruleset/*"
    ]
    sid = "ManageWAFRuleSet"
  }

  statement {
    actions = [
      "wafv2:DeleteIPSet",
      "wafv2:CreateIPSet",
      "wafv2:UpdateIPSet",
      "wafv2:TagResource",
      "wafv2:UntagResource"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/ipset/*",
      "arn:aws:wafv2:us-east-1:${var.account_id}:regional/ipset/*",
      "arn:aws:wafv2:eu-west-2:${var.account_id}:global/ipset/*",
      "arn:aws:wafv2:eu-west-2:${var.account_id}:regional/ipset/*"
    ]
    sid = "ManageIPSets"
  }
}
