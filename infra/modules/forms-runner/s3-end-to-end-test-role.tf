resource "aws_iam_role" "s3_end_to_end_test_role" {
  name               = "govuk-s3-end-to-end-test-${var.env_name}"
  assume_role_policy = data.aws_iam_policy_document.s3_end_to_end_test_role_policy.json
}


data "aws_iam_policy_document" "s3_end_to_end_test_role_policy" {
  source_policy_documents = compact([
    data.aws_iam_policy_document.allow_e2e_codebuild_to_assumerole.json,
    length(var.additional_submissions_to_s3_role_assumers) > 0 ? data.aws_iam_policy_document.allow_additional_submissions_to_s3_role_assumers.json : null
  ])
}

resource "aws_iam_role_policy" "allow_s3_actions_for_e2e_tests" {
  role = aws_iam_role.s3_end_to_end_test_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowAllS3Actions"
        Action   = "s3:*"
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::*"]
      }
    ]
  })
}

data "aws_iam_policy_document" "allow_e2e_codebuild_to_assumerole" {
  statement {
    effect = "Allow"
    principals {
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/codebuild-e2e-tests-${var.env_name}",
        "arn:aws:iam::${var.deploy_account_id}:role/codebuild-docker-build-e2e-tests"
      ]
      type = "AWS"
    }
    actions = ["sts:AssumeRole"]
  }
}
