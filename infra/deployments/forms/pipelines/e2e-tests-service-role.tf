data "aws_iam_policy_document" "e2e_service_role_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "e2e_service_role" {
  name               = "codebuild-e2e-tests-${var.environment_name}"
  assume_role_policy = data.aws_iam_policy_document.e2e_service_role_assume_role.json
}

data "aws_iam_policy_document" "e2e_service_role" {
  statement {
    sid    = "WriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:eu-west-2:${data.aws_caller_identity.current.account_id}:log-group:codebuild/*-e2e-tests-${var.environment_name}:*"
    ]
  }

  statement {
    sid    = "UseCodeStarConnection"
    effect = "Allow"
    actions = [
      "codestar-connections:UseConnection",
      "codestar-connections:GetConnection",
      "codestar-connections:ListConnections"
    ]
    resources = [var.codestar_connection_arn]
  }

  statement {
    sid    = "GetEcrAuthToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PullE2eImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = [
      "arn:aws:ecr:eu-west-2:${var.deploy_account_id}:repository/end-to-end-tests"
    ]
  }

  statement {
    sid    = "ReadTestParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/${var.environment_name}/automated-tests/e2e/*",
      "arn:aws:ssm:eu-west-2:${data.aws_caller_identity.current.account_id}:parameter/forms-runner-${var.environment_name}/submission_status_api_shared_secret"
    ]
  }

  statement {
    sid    = "ReadWriteArtifactBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "${module.artifact_bucket.arn}/*",
      module.artifact_bucket.arn
    ]
  }

  statement {
    sid    = "AssumeS3EndToEndTestRole"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/govuk-s3-end-to-end-test-${var.environment_name}"
    ]
  }

  statement {
    sid    = "PublishTestResultEvents"
    effect = "Allow"
    actions = [
      "events:PutEvents"
    ]
    resources = [
      "arn:aws:events:eu-west-2:${data.aws_caller_identity.current.account_id}:event-bus/default"
    ]
  }
}

resource "aws_iam_policy" "e2e_service_role" {
  name   = "codebuild-e2e-tests-${var.environment_name}"
  policy = data.aws_iam_policy_document.e2e_service_role.json
}

resource "aws_iam_role_policy_attachment" "e2e_service_role" {
  policy_arn = aws_iam_policy.e2e_service_role.arn
  role       = aws_iam_role.e2e_service_role.id
}
