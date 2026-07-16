module "error_page_bucket" {
  source = "../public-bucket"

  access_logging_enabled = true
  name                   = "govuk-forms-${var.env_name}-error-page"
}

locals {
  assets_bucket_name = "govuk-forms-${var.env_name}-assets"
}

module "assets_bucket" {
  source = "../secure-bucket"

  name                      = local.assets_bucket_name
  access_logging_enabled    = true
  send_access_logs_to_cyber = var.send_logs_to_cyber

  extra_bucket_policies = [data.aws_iam_policy_document.assets_bucket_cloudfront_read.json]
}

data "aws_iam_policy_document" "assets_bucket_cloudfront_read" {
  statement {
    sid = "AllowCloudFrontToReadAssets"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::${local.assets_bucket_name}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "assets" {
  name                              = "assets-${var.env_name}"
  description                       = "Allow the CloudFront distribution to access the assets bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  content_type_map = {
    "js"    = "application/json"
    "html"  = "text/html"
    "css"   = "text/css"
    "png"   = "image/png"
    "jpg"   = "image/jpeg"
    "svg"   = "image/svg+xml"
    "woff"  = "font/woff"
    "woff2" = "font/woff2"
    "ico"   = "image/x-icon"
  }
}

resource "aws_s3_object" "error_page_html" {
  for_each = fileset("${path.module}/html/", "**")

  bucket       = module.error_page_bucket.name
  key          = "/cloudfront/${each.value}"
  source       = "${path.module}/html/${each.value}"
  content_type = lookup(local.content_type_map, reverse(split(".", each.value))[0], "binary/octet-stream")
  etag         = filemd5("${path.module}/html/${each.value}")
}
