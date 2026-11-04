module "all_accounts" {
  source = "../../../modules/all-accounts"
}

locals {
  # Staging and production promote images by retagging them. Development
  # deploys images but never promotes them, so it must not be able to push
  # tags that staging or production deploy.
  promoting_deployer_roles = [
    for acct, id in module.all_accounts.environment_accounts_id :
    "arn:aws:iam::${id}:role/deployer-${acct}"
    if acct != "development"
  ]
}


resource "aws_ecr_repository" "forms_runner" {
  #checkov:skip=CKV_AWS_136:AWS Managed SSE is sufficient.
  #checkov:skip=CKV_AWS_51:Permit mutable tags on application images
  name                 = "forms-runner-deploy"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "forms_admin" {
  #checkov:skip=CKV_AWS_136:AWS Managed SSE is sufficient.
  #checkov:skip=CKV_AWS_51:Permit mutable tags on application images
  name                 = "forms-admin-deploy"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "forms_product_page" {
  #checkov:skip=CKV_AWS_136:AWS Managed SSE is sufficient.
  #checkov:skip=CKV_AWS_51:Permit mutable tags on application images
  name                 = "forms-product-page-deploy"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "end_to_end_tests" {
  #checkov:skip=CKV_AWS_136:AWS Managed SSE is sufficient.
  #checkov:skip=CKV_AWS_51:Permit mutable tags on pipeline images
  name                 = "end-to-end-tests"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "pipeline_visualiser" {
  #checkov:skip=CKV_AWS_136:AWS Managed SSE is sufficient.
  #checkov:skip=CKV_AWS_51:Permit mutable tags on pipeline images
  name                 = "pipeline-visualiser"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}



resource "aws_ecr_repository_policy" "aws_ecr_repository_policy_admin" {
  repository = aws_ecr_repository.forms_admin.name
  policy     = data.aws_iam_policy_document.aws_ecr_repository_policy_admin.json

}

data "aws_iam_policy_document" "aws_ecr_repository_policy_admin" {
  statement {
    sid    = "AllowEveryRoleInOtherAccountsToPullImages"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
    principals {
      type = "AWS"
      identifiers = [
        for _, id in module.all_accounts.all_accounts_id :
        "arn:aws:iam::${id}:root"
      ]
    }
  }

  statement {
    sid    = "AllowDeployerRolesToPushImages"
    effect = "Allow"
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage"
    ]
    principals {
      type        = "AWS"
      identifiers = local.promoting_deployer_roles
    }
  }
}

resource "aws_ecr_repository_policy" "aws_ecr_repository_policy_runner" {
  repository = aws_ecr_repository.forms_runner.name
  policy     = data.aws_iam_policy_document.aws_ecr_repository_policy_runner_document.json

}

data "aws_iam_policy_document" "aws_ecr_repository_policy_runner_document" {

  statement {
    sid    = "AllowEveryRoleInOtherAccountsToPullImages"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
    principals {
      type = "AWS"
      identifiers = [
        for _, id in module.all_accounts.all_accounts_id :
        "arn:aws:iam::${id}:root"
      ]
    }
  }

  statement {
    sid    = "AllowDeployerRolesToPushImages"
    effect = "Allow"
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage"
    ]
    principals {
      type        = "AWS"
      identifiers = local.promoting_deployer_roles
    }
  }
}

resource "aws_ecr_repository_policy" "aws_ecr_repository_policy_product_page" {
  repository = aws_ecr_repository.forms_product_page.name
  policy     = data.aws_iam_policy_document.aws_ecr_repository_policy_product_page_document.json
}

data "aws_iam_policy_document" "aws_ecr_repository_policy_product_page_document" {

  statement {
    sid    = "AllowEveryRoleInOtherAccountsToPullImages"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
    principals {
      type = "AWS"
      identifiers = [
        for _, id in module.all_accounts.all_accounts_id :
        "arn:aws:iam::${id}:root"
      ]
    }
  }

  statement {
    sid    = "AllowDeployerRolesToPushImages"
    effect = "Allow"
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage"
    ]
    principals {
      type        = "AWS"
      identifiers = local.promoting_deployer_roles
    }
  }
}

resource "aws_ecr_repository_policy" "aws_ecr_repository_policy_end_to_end_tests" {
  repository = aws_ecr_repository.end_to_end_tests.name
  policy     = data.aws_iam_policy_document.aws_ecr_repository_policy_end_to_end_tests.json
}

data "aws_iam_policy_document" "aws_ecr_repository_policy_end_to_end_tests" {

  statement {
    sid    = "AllowEveryRoleInOtherAccountsToPullImages"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetAuthorizationToken",
    ]
    principals {
      type = "AWS"
      identifiers = [
        for _, id in module.all_accounts.all_accounts_id :
        "arn:aws:iam::${id}:root"
      ]
    }
  }

  statement {
    sid    = "AllowDeployerRolesToPushImages"
    effect = "Allow"
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage"
    ]
    principals {
      type        = "AWS"
      identifiers = local.promoting_deployer_roles
    }
  }

}
