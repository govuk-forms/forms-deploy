output "review_dns_name_servers" {
  description = "The name servers to which control of the review domain should be delegated"
  value       = aws_route53_zone.review.name_servers
}

output "review_dns_zone_id" {
  description = "The id the AWS Route53 Hosted Zone for the review apps environment"
  value       = aws_route53_zone.review.id
}

output "codeconnection_arn" {
  description = "The ARN of the AWS Code Connection. These must be created by hand within the account."
  value       = "arn:aws:codeconnections:eu-west-2:842676007477:connection/b6356c43-c945-4575-8348-64c12d608d4c"
}

output "kinesis_subscription_role_arn" {
  value = aws_iam_role.kinesis_subscription_role.arn
}

output "github_oidc_provider_arn" {
  description = "The ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "destination_vault_arn" {
  value = aws_backup_vault.copy.arn
}