output "vpc_id" {
  value = aws_vpc.forms.id
}

output "vpc_cidr_block" {
  value = aws_vpc.forms.cidr_block
}

output "private_subnet_ids" {
  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]
}

output "alb_arn_suffix" {
  value = aws_lb.alb.arn_suffix
}

output "alb_arn" {
  value = aws_lb.alb.arn
}

output "alb_main_listener_arn" {
  value = aws_lb_listener.listener.arn
}

output "internal_alb_arn" {
  value = aws_lb.internal_alb.arn
}

output "internal_alb_arn_suffix" {
  value = aws_lb.internal_alb.arn_suffix
}

output "internal_alb_dns_name" {
  value = aws_lb.internal_alb.dns_name
}

output "internal_alb_listener_arn" {
  value = aws_lb_listener.internal_listener.arn
}

output "internal_alb_https_listener_arn" {
  value = aws_lb_listener.internal_https_listener.arn
}

output "internal_alb_zone_id" {
  value = aws_lb.internal_alb.zone_id
}

output "private_internal_zone_id" {
  value = data.aws_route53_zone.private_internal.zone_id
}

output "cloudfront_arn" {
  value = module.cloudfront[0].cloudfront_arn
}

output "cloudfront_distribution_id" {
  value = module.cloudfront[0].cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  value = module.cloudfront[0].cloudfront_domain_name
}

output "cloudfront_hosted_zone_id" {
  value = module.cloudfront[0].cloudfront_hosted_zone_id
}

output "cloudfront_secret" {
  value     = var.enable_cloudfront ? module.cloudfront[0].cloudfront_secret : null
  sensitive = true
}

output "eventbridge_dead_letter_queue_arn" {
  value = aws_sqs_queue.event_bridge_dlq.arn
}

output "eventbridge_dead_letter_queue_url" {
  value = aws_sqs_queue.event_bridge_dlq.url
}

output "zendesk_alert_us_east_1_topic_arn" {
  value = module.zendesk_alert_us_east_1.topic_arn
}

output "zendesk_alert_eu_west_2_topic_arn" {
  value = module.zendesk_alert_eu_west_2.topic_arn
}

output "pagerduty_eu_west_2_topic_arn" {
  value = module.pagerduty_eu_west_2.topic_arn
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.forms.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.forms.name
}

output "ecs_events_role_arn" {
  value = aws_iam_role.ecs_events.arn
}
