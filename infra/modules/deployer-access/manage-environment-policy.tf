data "aws_iam_policy_document" "environment" {
  source_policy_documents = [
    data.aws_iam_policy_document.acm_cert_with_dns_validation.json,
    data.aws_iam_policy_document.cloudfront.json,
    data.aws_iam_policy_document.public_bucket.json,
    data.aws_iam_policy_document.secure_bucket.json,
    data.aws_iam_policy_document.network.json,
  ]
}

resource "aws_iam_policy" "environment" {
  policy = data.aws_iam_policy_document.environment.json
}

resource "aws_iam_role_policy_attachment" "environment" {
  policy_arn = aws_iam_policy.environment.arn
  role       = aws_iam_role.deployer.id
}

data "aws_iam_policy_document" "acm_cert_with_dns_validation" {
  statement {
    sid    = "ManageCertificates"
    effect = "Allow"
    actions = [
      "acm:*Certificate*",
    ]
    resources = [
      # TODO: Why does it need both regions?
      # https://trello.com/c/enOX8GRF/3454-investigate-why-policy-document-acmcertwithdnsvalidation-needs-access-to-both-eu-west-2-and-us-east-1
      "arn:aws:acm:eu-west-2:${var.account_id}:certificate/*",
      "arn:aws:acm:us-east-1:${var.account_id}:certificate/*"
    ]
  }

  statement {
    sid    = "ListHostedZones"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
    ]
    resources = [
      "*"
    ]
  }

  # duplicate
  statement {
    sid    = "ManageRoute53RecordSets"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${var.hosted_zone_id}",
      "arn:aws:route53:::hostedzone/${var.private_internal_zone_id}"
    ]
  }
}

data "aws_iam_policy_document" "cloudfront" {
  #checkov:skip=CKV_AWS_356
  statement {
    sid    = "ManageCloudfrontDistribution"
    effect = "Allow"
    actions = [
      "cloudfront:AssociateAlias",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:*Distribution*",
    ]
    resources = [
      "arn:aws:cloudfront::${var.account_id}:distribution/*"
    ]
  }

  statement {
    sid    = "GetPoliciesCloudfront"
    effect = "Allow"
    actions = [
      "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:GetCachePolicy",
      "cloudfront:GetOriginRequestPolicy",
      "cloudfront:ListResponseHeadersPolicies",
      "cloudfront:ListCachePolicies",
      "cloudfront:ListOriginRequestPolicies",
    ]
    resources = [
      "arn:aws:cloudfront::${var.account_id}:*"
    ]
  }

  statement {
    sid    = "ManageWAFv2WebACL"
    effect = "Allow"
    actions = [
      "wafv2:*WebACL",
      "wafv2:*LoggingConfiguration",
      "wafv2:ListTagsForResource",
      "wafv2:TagResource",
      "wafv2:UntagResource",
      "wafv2:*RuleGroup",
      "wafv2:*RegexPatternSet",
    ]
    # TODO: The scope of this should be cloudfront but for some reason it needs global
    # https://trello.com/c/JCyMcRip/3455-investigate-why-managewafv2webacl-needs-global-scope-instead-of-just-cloudfront
    resources = [
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/webacl/cloudfront_waf_${var.environment_name}/*",
      "arn:aws:wafv2:eu-west-2:${var.account_id}:regional/webacl/alb_${var.environment_name}/*",
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/ipset/${var.environment_name}-*",
      "arn:aws:wafv2:eu-west-2:${var.account_id}:regional/ipset/${var.environment_name}-*",
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/rulegroup/${var.environment_name}-*/*",
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/regexpatternset/${var.environment_name}-*",

      # This ARN pattern is owned by AWS, but we make a change to it when we override part of the rule
      "arn:aws:wafv2:us-east-1:153427709519:global/rulegroup/ShieldMitigationRuleGroup_*"
    ]
  }

  statement {
    sid    = "ManageWAFRuleSet"
    effect = "Allow"
    actions = [
      "wafv2:CreateWebACL",
      "wafv2:PutManagedRuleSetVersions",
      "wafv2:UpdateWebACL",
    ]
    resources = [
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/managedruleset/*"
    ]
  }

  statement {
    sid    = "ManageIPSets"
    effect = "Allow"
    actions = [
      "wafv2:DeleteIPSet",
      "wafv2:CreateIPSet",
      "wafv2:UpdateIPSet",
      "wafv2:TagResource",
      "wafv2:UntagResource",
    ]
    resources = [
      "arn:aws:wafv2:us-east-1:${var.account_id}:global/ipset/*",
      "arn:aws:wafv2:us-east-1:${var.account_id}:regional/ipset/*",
      "arn:aws:wafv2:eu-west-2:${var.account_id}:global/ipset/*",
      "arn:aws:wafv2:eu-west-2:${var.account_id}:regional/ipset/*",
    ]
  }

  statement {
    sid    = "ManageWebACL"
    effect = "Allow"
    actions = [
      "wafv2:*LoggingConfiguration",
      "wafv2:CreateWebACL",
      "wafv2:DeleteWebACL",
      "wafv2:UpdateWebACL",
    ]
    resources = [
      "arn:aws:wafv2:us-east-1:${var.account_id}:regional/webacl/*",
      "arn:aws:wafv2:eu-west-2:${var.account_id}:regional/webacl/*"
    ]
  }

  statement {
    sid    = "ManageCloudwatchLogsWAF"
    effect = "Allow"
    actions = [
      "logs:*LogEvents",
      "logs:*LogStream",
      "logs:*SubscriptionFilters",
      "logs:*SubscriptionFilter",
      "logs:*LogGroup",
      "logs:PutRetentionPolicy",
    ]
    resources = [
      "arn:aws:logs:us-east-1:${var.account_id}:log-group:aws-waf-logs-${var.environment_name}*",
      "arn:aws:logs:eu-west-2:${var.account_id}:log-group:aws-waf-logs-alb-${var.environment_name}*"
    ]
  }

  statement {
    sid    = "ManageCloudwatchLogs"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:*LogDelivery",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:TagResource"
    ]
    resources = [
      "*",
    ]
  }

  statement {
    sid    = "CreateServiceLinkedRoleForWAF"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:role/*"
    ]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["wafv2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "public_bucket" {
  statement {
    sid    = "ManageErrorPageBucket"
    effect = "Allow"
    actions = [
      "s3:*Configuration",
      "s3:*Bucket*",
      "s3:*Object*",
    ]
    resources = [
      "arn:aws:s3:::govuk-forms-${var.environment_name}-error-page*"
    ]
  }
}

data "aws_iam_policy_document" "secure_bucket" {
  statement {
    sid    = "ManageALBandWAFLogsBucket"
    effect = "Allow"
    actions = [
      "s3:*Configuration",
      "s3:*Bucket*",
      "s3:*Object*",
    ]
    resources = [
      "arn:aws:s3:::govuk-forms-alb-logs-${var.environment_name}*",
    ]
  }
}

data "aws_iam_policy_document" "network" {
  statement {
    sid    = "ManageNetwork"
    effect = "Allow"
    actions = [
      "ec2:*VpcEndpoint*",
      "ec2:*SecurityGroup*",
      "ec2:*NatGateway*",
      "ec2:*Address",
      "ec2:*Subnet*",
      "ec2:*RouteTable",
      "ec2:*RouteTableAssociation",
      "ec2:*Vpc",
      "ec2:*InternetGateway*",
    ]
    resources = [
      "arn:aws:ec2:eu-west-2:${var.account_id}:*"
    ]
  }

  statement {
    sid = "DenyTransitGateway"
    # because we don't want it doing transit gateway things
    effect = "Deny"
    actions = [
      "ec2:*TransitGatewayRouteTable",
    ]
    resources = [
      "arn:aws:ec2:eu-west-2:${var.account_id}:*"
    ]
  }
}
