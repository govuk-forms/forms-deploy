output "alb_dns_name" {
  value = aws_lb.grafana.dns_name
}

output "alb_zone_id" {
  value = aws_lb.grafana.zone_id
}
