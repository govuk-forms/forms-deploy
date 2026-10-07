resource "aws_kinesis_firehose_delivery_stream" "submission_events" {
  name        = local.stream_name
  destination = "iceberg"

  # No customer-managed key: the data is not sensitive, the AWS-owned key is
  # free and needs no management.
  #checkov:skip=CKV_AWS_241:An AWS-owned key is sufficient, no need for CM KMS.
  server_side_encryption {
    enabled  = true
    key_type = "AWS_OWNED_CMK"
  }

  iceberg_configuration {
    role_arn           = aws_iam_role.firehose_delivery.arn
    catalog_arn        = "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog/s3tablescatalog/${local.table_bucket_name}"
    buffering_interval = var.firehose_buffering_interval_seconds

    destination_table_configuration {
      database_name = local.namespace_name
      table_name    = local.table_name
    }

    s3_configuration {
      role_arn   = aws_iam_role.firehose_delivery.arn
      bucket_arn = module.error_bucket.arn
    }

    # Records arrive as gzipped CloudWatch Logs envelopes. The built-in
    # Decompression processor is not supported for the Iceberg destination, so
    # a Lambda unwraps the envelope instead (see lambda/transform.rb).
    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"
        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${aws_lambda_function.transform.arn}:$LATEST"
        }
      }
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_delivery.name
    }
  }

  # Firehose validates at creation time that the destination table exists and
  # is reachable through the federated catalog
  depends_on = [aws_glue_catalog.s3tablescatalog, aws_s3tables_table.submission_events]
}

resource "aws_cloudwatch_log_group" "firehose" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Default AWS SSE is sufficient, no need for CM KMS.
  name              = "/aws/kinesisfirehose/${local.stream_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "firehose_delivery" {
  name           = "DestinationDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}
