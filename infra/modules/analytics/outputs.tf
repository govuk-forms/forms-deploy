output "table_bucket_name" {
  value = aws_s3tables_table_bucket.forms_analytics.name
}

output "table_bucket_arn" {
  value = aws_s3tables_table_bucket.forms_analytics.arn
}
