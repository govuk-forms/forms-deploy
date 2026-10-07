# Role assumed by Firehose to write to the S3 Table and the error bucket
resource "aws_iam_role" "firehose_delivery" {
  name               = "govuk-forms-submission-events-firehose-${var.env_name}"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}

data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role_policy" "firehose_delivery" {
  name   = "deliver-submission-events"
  role   = aws_iam_role.firehose_delivery.id
  policy = data.aws_iam_policy_document.firehose_delivery.json
}

data "aws_iam_policy_document" "firehose_delivery" {
  statement {
    sid    = "ReadAndWriteTableData"
    effect = "Allow"
    actions = [
      "s3tables:GetTableBucket",
      "s3tables:GetNamespace",
      "s3tables:GetTable",
      "s3tables:GetTableData",
      "s3tables:GetTableMetadataLocation",
      "s3tables:PutTableData",
      "s3tables:UpdateTableMetadataLocation"
    ]
    resources = [
      aws_s3tables_table_bucket.forms_analytics.arn,
      "${aws_s3tables_table_bucket.forms_analytics.arn}/table/*"
    ]
  }

  statement {
    sid    = "AccessTableThroughGlueCatalog"
    effect = "Allow"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:UpdateTable"
    ]
    # Databases and tables in the federated catalog have the catalog path
    # embedded in their ARNs (e.g. table/s3tablescatalog/<bucket>/<ns>/<table>)
    resources = [
      "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog/s3tablescatalog",
      "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog/s3tablescatalog/${local.table_bucket_name}",
      "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:database/s3tablescatalog/${local.table_bucket_name}/${local.namespace_name}",
      "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/s3tablescatalog/${local.table_bucket_name}/${local.namespace_name}/*"
    ]
  }

  statement {
    sid    = "WriteUndeliveredRecordsToErrorBucket"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [
      module.error_bucket.arn,
      "${module.error_bucket.arn}/*"
    ]
  }

  statement {
    sid    = "InvokeTransformLambda"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunctionConfiguration"
    ]
    resources = ["${aws_lambda_function.transform.arn}:$LATEST"]
  }

  statement {
    sid       = "WriteDeliveryErrorLogs"
    effect    = "Allow"
    actions   = ["logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.firehose.arn}:log-stream:*"]
  }
}

# Role assumed by CloudWatch Logs to put log events onto the Firehose stream
resource "aws_iam_role" "log_subscription" {
  name               = "govuk-forms-submission-events-subscription-${var.env_name}"
  assume_role_policy = data.aws_iam_policy_document.log_subscription_assume_role.json
}

data "aws_iam_policy_document" "log_subscription_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["logs.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_iam_role_policy" "log_subscription" {
  name   = "put-records-to-firehose"
  role   = aws_iam_role.log_subscription.id
  policy = data.aws_iam_policy_document.log_subscription.json
}

data "aws_iam_policy_document" "log_subscription" {
  statement {
    effect = "Allow"
    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch"
    ]
    resources = [aws_kinesis_firehose_delivery_stream.submission_events.arn]
  }
}
