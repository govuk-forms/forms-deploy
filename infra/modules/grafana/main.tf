data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name           = "grafana"
  container_port = 3000
  host_name      = "grafana.${var.root_domain}"
  ssm_prefix     = "/grafana"
}
