output "route53_hosted_zone_id" {
  value = aws_route53_zone.public.id
}

output "private_internal_zone_id" {
  value = aws_route53_zone.private_internal.id
}

output "internal_digital_hosted_zone_id" {
  value = aws_route53_zone.internal_digital.id
}

output "internal_digital_name_servers" {
  value = aws_route53_zone.internal_digital.name_servers
}

output "kinesis_subscription_role_arn" {
  value = aws_iam_role.kinesis_subscription_role.arn
}
