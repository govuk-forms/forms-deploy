output "firehose_stream_arn" {
  value = aws_kinesis_firehose_delivery_stream.submission_events.arn
}

output "table_bucket_name" {
  value = aws_s3tables_table_bucket.forms_analytics.name
}

output "table_bucket_arn" {
  value = aws_s3tables_table_bucket.forms_analytics.arn
}

output "error_bucket_name" {
  value = module.error_bucket.name
}
