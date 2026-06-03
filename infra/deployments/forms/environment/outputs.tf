output "vpc_id" {
  value = module.environment.vpc_id
}

output "vpc_cidr_block" {
  value = module.environment.vpc_cidr_block
}

output "private_subnet_ids" {
  value = module.environment.private_subnet_ids
}

output "alb_arn_suffix" {
  value = module.environment.alb_arn_suffix
}

output "alb_arn" {
  value = module.environment.alb_arn
}

output "alb_main_listener_arn" {
  value = module.environment.alb_main_listener_arn
}

output "internal_alb_listener_arn" {
  value = module.environment.internal_alb_listener_arn
}

output "internal_alb_https_listener_arn" {
  value = module.environment.internal_alb_https_listener_arn
}

output "cloudfront_arn" {
  value = module.environment.cloudfront_arn
}

output "cloudfront_distribution_id" {
  value = module.environment.cloudfront_distribution_id
}

output "cloudfront_distribution_domain_name" {
  value = module.environment.cloudfront_domain_name
}

output "cloudfront_hosted_zone_id" {
  value = module.environment.cloudfront_hosted_zone_id
}

output "cloudfront_secret" {
  value     = module.environment.cloudfront_secret
  sensitive = true
}

output "eventbridge_dead_letter_queue_arn" {
  value = module.environment.eventbridge_dead_letter_queue_arn
}

output "eventbridge_dead_letter_queue_url" {
  value = module.environment.eventbridge_dead_letter_queue_url
}

output "zendesk_alert_us_east_1_topic_arn" {
  value = module.environment.zendesk_alert_us_east_1_topic_arn
}

output "zendesk_alert_eu_west_2_topic_arn" {
  value = module.environment.zendesk_alert_eu_west_2_topic_arn
}

output "pagerduty_eu_west_2_topic_arn" {
  value = module.environment.pagerduty_eu_west_2_topic_arn
}

output "ecs_cluster_arn" {
  value = module.environment.ecs_cluster_arn
}

output "ecs_cluster_name" {
  value = module.environment.ecs_cluster_name
}

output "ecs_events_role_arn" {
  value = module.environment.ecs_events_role_arn
}

output "private_internal_zone_id" {
  value = module.environment.private_internal_zone_id
}

output "internal_alb_dns_name" {
  value = module.environment.internal_alb_dns_name
}

output "internal_alb_zone_id" {
  value = module.environment.internal_alb_zone_id
}
