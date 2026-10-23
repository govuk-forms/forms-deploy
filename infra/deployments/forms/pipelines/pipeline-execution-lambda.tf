##
# AWS EventBridge does invoke AWS CodePipeline
# using the output of the input transformer as the
# documentation suggests it does. This is a problem
# for us because we need to pass variable values to
# the AWS CodePipeline execution.
#
# To work around this we've created a simple AWS Lambda
# function which performs the function that AWS EventBridge
# doesn't/can't
##

module "lambda_bucket" {
  source = "../../../modules/secure-bucket"

  name                   = "govuk-forms-${var.environment_name}-pipeline-invoker"
  access_logging_enabled = true
}

resource "aws_lambda_function" "pipeline_invoker" {
  #checkov:skip=CKV_AWS_272:we're not doing code signing on this lambda at the moment
  #checkov:skip=CKV_AWS_116:no dead letter queue at this time
  #checkov:skip=CKV_AWS_117:lambda does not need access to things inside the VPC
  #checkov:skip=CKV_AWS_50 :not using X-Ray

  function_name = "${var.environment_name}-pipeline-invoker"
  description   = "Receives events from AWS EventBridge and invokes AWS CodePipeline in turn. A replacement for missing functionality in AWS EventBridge"
  role          = aws_iam_role.lambda_pipeline_invoker.arn

  runtime                        = "ruby3.4"
  architectures                  = ["arm64"]
  handler                        = "pipeline_invoker.process"
  reserved_concurrent_executions = 50
  timeout                        = 10

  s3_bucket = module.lambda_bucket.name
  s3_key    = "invoker-lambda.zip"

  source_code_hash = data.archive_file.invoker.output_base64sha256

  depends_on = [aws_s3_object.invoker]
}

resource "aws_cloudwatch_log_group" "pipeline_invoker_log_group" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  name              = "/aws/lambda/${aws_lambda_function.pipeline_invoker.function_name}"
  retention_in_days = 30
}

data "archive_file" "invoker" {
  type        = "zip"
  source_dir  = "${path.module}/pipeline-invoker"
  output_path = "${path.module}/zip-files/inokver-lambda.zip"
}

resource "aws_s3_object" "invoker" {
  bucket = module.lambda_bucket.name

  key         = "invoker-lambda.zip"
  source      = data.archive_file.invoker.output_path
  source_hash = data.archive_file.invoker.output_md5
}

resource "aws_iam_role" "lambda_pipeline_invoker" {
  name = "${var.environment_name}-lambda-pipeline-invoker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = "AllowLambdaToAssume"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

data "aws_iam_policy_document" "allow_pipeline_invocation" {
  statement {
    effect    = "Allow"
    actions   = ["codepipeline:StartPipelineExecution"]
    resources = ["arn:aws:codepipeline:eu-west-2:${data.aws_caller_identity.current.account_id}:*"]
  }
}

resource "aws_iam_role_policy_attachment" "basic_lambda_policy" {
  role       = aws_iam_role.lambda_pipeline_invoker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "allow_pipeline_invocation" {
  role   = aws_iam_role.lambda_pipeline_invoker.name
  policy = data.aws_iam_policy_document.allow_pipeline_invocation.json
}

resource "aws_lambda_permission" "allow_event_bridge" {
  #checkov:skip=CKV_AWS_364:we WANT to allow every EventBridge target to invoke this Lambda
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pipeline_invoker.function_name
  principal     = "events.amazonaws.com"
}
