resource "aws_route53_record" "grafana" {
  #checkov:skip=CKV2_AWS_23:Not applicable to alias records
  count   = var.grafana_settings.enabled ? 1 : 0
  zone_id = data.terraform_remote_state.account.outputs.route53_hosted_zone_id
  name    = "grafana.${var.root_domain}"
  type    = "A"

  alias {
    name                   = data.terraform_remote_state.forms_health.outputs.grafana_alb_dns_name
    zone_id                = data.terraform_remote_state.forms_health.outputs.grafana_alb_zone_id
    evaluate_target_health = true
  }
}
