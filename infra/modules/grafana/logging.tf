locals {
  log_group_name = "/aws/ecs/${local.name}"
}

resource "aws_cloudwatch_log_group" "grafana" {
  #checkov:skip=CKV_AWS_338:We're happy with 30 days retention for now
  #checkov:skip=CKV_AWS_158:Default AWS SSE is sufficient, no need for CM KMS.
  name              = local.log_group_name
  retention_in_days = 30
}

module "cribl_well_known" {
  source = "../well-known/cribl"
}

resource "aws_cloudwatch_log_subscription_filter" "via_cribl_to_splunk" {
  count = var.kinesis_subscription_role_arn != "" ? 1 : 0

  name = "via-cribl-to-splunk"

  log_group_name = aws_cloudwatch_log_group.grafana.name

  filter_pattern  = ""
  destination_arn = module.cribl_well_known.kinesis_destination_arns["eu-west-2"]
  distribution    = "ByLogStream"
  role_arn        = var.kinesis_subscription_role_arn
}
