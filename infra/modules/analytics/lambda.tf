data "archive_file" "transform" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/zip-files/transform-lambda.zip"
}

resource "aws_lambda_function" "transform" {
  #checkov:skip=CKV_AWS_272:we're not doing code signing on this lambda at the moment
  #checkov:skip=CKV_AWS_116:no dead letter queue, failed invocations are written to the error bucket instead
  #checkov:skip=CKV_AWS_117:lambda does not need access to things inside the VPC
  #checkov:skip=CKV_AWS_50 :not using X-Ray
  #checkov:skip=CKV_AWS_173:the value in the environment variable does not need encrypting

  function_name = local.transform_function_name
  description   = "Puts form submission log events from CloudWatch Logs to the submission events Firehose stream"
  role          = aws_iam_role.transform_lambda.arn

  runtime                        = "ruby3.4"
  handler                        = "transform.handler"
  reserved_concurrent_executions = 10
  timeout                        = 120
  memory_size                    = 256

  filename         = data.archive_file.transform.output_path
  source_code_hash = data.archive_file.transform.output_base64sha256

  environment {
    variables = {
      STREAM_NAME = aws_kinesis_firehose_delivery_stream.submission_events.name
    }
  }

  # Otherwise Lambda creates the log group itself on first invocation, without
  # a retention period, and creating it here then fails
  depends_on = [aws_cloudwatch_log_group.transform_lambda]
}

# CloudWatch Logs invokes the function asynchronously. If an invocation still
# fails after Lambda's retries, the event is written to the error bucket.
resource "aws_lambda_function_event_invoke_config" "transform" {
  function_name          = aws_lambda_function.transform.function_name
  maximum_retry_attempts = 2

  destination_config {
    on_failure {
      destination = module.error_bucket.arn
    }
  }

  depends_on = [aws_iam_role_policy.transform_lambda]
}

resource "aws_cloudwatch_log_group" "transform_lambda" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  name              = "/aws/lambda/${local.transform_function_name}"
  retention_in_days = 30
}

resource "aws_iam_role" "transform_lambda" {
  name               = "govuk-forms-submission-events-transform-${var.env_name}"
  assume_role_policy = data.aws_iam_policy_document.transform_lambda_assume_role.json
}

data "aws_iam_policy_document" "transform_lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "transform_lambda_basic" {
  role       = aws_iam_role.transform_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "transform_lambda" {
  name   = "put-submission-events"
  role   = aws_iam_role.transform_lambda.id
  policy = data.aws_iam_policy_document.transform_lambda.json
}

data "aws_iam_policy_document" "transform_lambda" {
  statement {
    sid       = "PutRecordsToStream"
    effect    = "Allow"
    actions   = ["firehose:PutRecordBatch"]
    resources = [aws_kinesis_firehose_delivery_stream.submission_events.arn]
  }

  statement {
    sid    = "WriteFailedInvocationsToErrorBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      module.error_bucket.arn,
      "${module.error_bucket.arn}/*"
    ]
  }
}
