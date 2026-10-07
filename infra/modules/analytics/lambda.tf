data "archive_file" "transform" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/zip-files/transform-lambda.zip"
}

resource "aws_lambda_function" "transform" {
  #checkov:skip=CKV_AWS_272:we're not doing code signing on this lambda at the moment
  #checkov:skip=CKV_AWS_116:no dead letter queue, Firehose retries and then writes failures to the error bucket
  #checkov:skip=CKV_AWS_117:lambda does not need access to things inside the VPC
  #checkov:skip=CKV_AWS_50 :not using X-Ray

  function_name = "submission-events-transform-${var.env_name}"
  description   = "Unwraps CloudWatch Logs records for the submission events Firehose stream"
  role          = aws_iam_role.transform_lambda.arn

  runtime                        = "ruby3.4"
  handler                        = "transform.handler"
  reserved_concurrent_executions = 10
  timeout                        = 120
  memory_size                    = 256

  filename         = data.archive_file.transform.output_path
  source_code_hash = data.archive_file.transform.output_base64sha256
}

resource "aws_cloudwatch_log_group" "transform_lambda" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  name              = "/aws/lambda/${aws_lambda_function.transform.function_name}"
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
