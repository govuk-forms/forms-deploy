resource "aws_iam_role" "submissions_to_s3_role" {
  name               = "govuk-forms-submissions-to-s3-${var.env_name}"
  assume_role_policy = data.aws_iam_policy_document.submissions_to_s3_assume_role_policy.json
}

data "aws_iam_policy_document" "submissions_to_s3_assume_role_policy" {
  source_policy_documents = compact([
    data.aws_iam_policy_document.allow_ecs_task_role_to_assumerole.json,
    length(var.additional_submissions_to_s3_role_assumers) > 0 ? data.aws_iam_policy_document.allow_additional_submissions_to_s3_role_assumers.json : null
  ])
}

data "aws_iam_policy_document" "allow_ecs_task_role_to_assumerole" {
  statement {
    effect = "Allow"
    principals {
      identifiers = [module.ecs_service.task_role_arn]
      type        = "AWS"
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "allow_additional_submissions_to_s3_role_assumers" {
  statement {
    effect = "Allow"
    principals {
      identifiers = var.additional_submissions_to_s3_role_assumers
      type        = "AWS"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "allow_s3_actions" {
  role = aws_iam_role.submissions_to_s3_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Departments choose which bucket receives their submissions, so we cannot list the buckets here
        Sid      = "AllowWritingSubmissionsToFormBuckets"
        Action   = "s3:PutObject"
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::*/*"]
      },
      {
        Sid      = "AllowReadingUploadedFilesToCopy"
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::${local.file_upload_bucket_name}/*"]
      }
    ]
  })
}
