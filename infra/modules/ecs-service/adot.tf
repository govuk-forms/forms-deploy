data "aws_region" "current" {}

resource "aws_ssm_parameter" "adot_collector_config" {
  #checkov:skip=CKV2_AWS_34:Not a secret; the config template is committed to this public repository
  #checkov:skip=CKV2_FORMS_AWS_7:Value is not a secret set outside Terraform; it must track changes to the config template

  count = var.enable_opentelemetry ? 1 : 0

  name = "/${var.application}-${var.env_name}/adot-collector-config"
  type = "String"
  value = templatefile("${path.module}/adot-collector-config.yaml.tpl", {
    aws_region = data.aws_region.current.region
    env_name   = var.env_name
  })

  description = "OpenTelemetry collector configuration for the ${var.application} ADOT sidecar in ${var.env_name}"
}
