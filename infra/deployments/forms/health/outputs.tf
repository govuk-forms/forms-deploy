output "grafana_alb_dns_name" {
  value = try(module.grafana[0].alb_dns_name, null)
}

output "grafana_alb_zone_id" {
  value = try(module.grafana[0].alb_zone_id, null)
}
