output "cloudfront_dns_name" {
  value = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_arn" {
  value = aws_cloudfront_distribution.main.arn
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_hosted_zone_id" {
  value = aws_cloudfront_distribution.main.hosted_zone_id
}

output "cloudfront_secret" {
  value     = random_password.cloudfront_secret.result
  sensitive = true
}

output "assets_bucket_name" {
  value = module.assets_bucket.name
}
