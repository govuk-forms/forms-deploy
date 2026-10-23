module "paused_pipeline_lambda_bucket" {
  source = "../../../modules/secure-bucket"

  name                   = "govuk-forms-${var.environment_name}-paused-pipeline-detection"
  access_logging_enabled = true
}

## Lambda
resource "aws_lambda_function" "paused_pipeline_detection" {
  #checkov:skip=CKV_AWS_272:we're not doing code signing on this lambda at the moment
  #checkov:skip=CKV_AWS_116:no dead letter queue at this time
  #checkov:skip=CKV_AWS_117:lambda does not need access to things inside the VPC
  #checkov:skip=CKV_AWS_50 :not using X-Ray
  #checkov:skip=CKV_AWS_45 :the value in the environment variable is not secret
  #checkov:skip=CKV_AWS_173:the value in the environment variable does not need encrypting

  function_name = "${var.environment_name}-paused-pipeline-detection"
  description   = "Searches for, and alerts us about, pipelines that have been paused for too long"
  role          = aws_iam_role.lambda_paused_pipeline_invoker.arn

  runtime                        = "ruby3.4"
  architectures                  = ["arm64"]
  handler                        = "index.main"
  reserved_concurrent_executions = 50
  timeout                        = 10

  s3_bucket = module.paused_pipeline_lambda_bucket.name
  s3_key    = "paused-pipeline-lambda.zip"

  source_code_hash = data.archive_file.paused_pipeline.output_base64sha256

  environment {
    variables = {
      "SLACK_SNS_TOPIC"        = "arn:aws:sns:eu-west-2:${var.deploy_account_id}:CodeStarNotifications-govuk-forms-alert-b7410628fe547543676d5dc062cf342caba48bcd",
      "FORMS_AWS_ACCOUNT_NAME" = var.account_name
    }
  }

  depends_on = [aws_s3_object.paused_pipeline]
}

resource "aws_lambda_permission" "paused_pipeline_allow_event_bridge" {
  #checkov:skip=CKV_AWS_364:we WANT to allow every EventBridge target to invoke this Lambda
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.paused_pipeline_detection.function_name
  principal     = "events.amazonaws.com"
}

## Logging
resource "aws_cloudwatch_log_group" "paused_pipeline_log_group" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Amazon managed SSE is sufficient.
  name              = "/aws/lambda/${aws_lambda_function.paused_pipeline_detection.function_name}"
  retention_in_days = 30
}

## Source code
data "archive_file" "paused_pipeline" {
  type        = "zip"
  source_dir  = abspath("${path.root}/../../../../support/paused-pipeline-detector")
  output_path = "${path.module}/zip-files/paused-pipeline-lambda.zip"
}

resource "aws_s3_object" "paused_pipeline" {
  bucket = module.paused_pipeline_lambda_bucket.name

  key         = "paused-pipeline-lambda.zip"
  source      = data.archive_file.paused_pipeline.output_path
  source_hash = data.archive_file.paused_pipeline.output_md5
}

## IAM
resource "aws_iam_role" "lambda_paused_pipeline_invoker" {
  name = "${var.environment_name}-lambda-paused-pipeline-invoker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = "AllowLambdaToAssume"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "paused_pipeline_basic_lambda_policy" {
  role       = aws_iam_role.lambda_paused_pipeline_invoker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "paused_pipeline_codepipeline_readonly" {
  role       = aws_iam_role.lambda_paused_pipeline_invoker.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_ReadOnlyAccess"
}
resource "aws_iam_role_policy" "paused_pipeline_allow_sns_publish" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = [aws_lambda_function.paused_pipeline_detection.environment[0].variables["SLACK_SNS_TOPIC"]]
    }]
  })
  role = aws_iam_role.lambda_paused_pipeline_invoker.name
}

## Scheduling
resource "aws_cloudwatch_event_rule" "paused_pipeline_schedule" {
  name                = "paused-pipeline-detector-on-${var.environment_name}"
  description         = "Trigger the paused pipeline detection on a schedule"
  schedule_expression = var.paused-pipeline-detection.trigger_schedule_expression
}

resource "aws_cloudwatch_event_target" "trigger_paused_pipeline_detector" {
  rule      = aws_cloudwatch_event_rule.paused_pipeline_schedule.name
  target_id = "trigger_lambda"
  arn       = aws_lambda_function.paused_pipeline_detection.arn

  dead_letter_config {
    arn = var.dlq_arn
  }
}
