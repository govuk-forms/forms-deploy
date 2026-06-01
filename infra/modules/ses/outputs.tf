output "form_submissions_configuration_set_name" {
  description = "The name of the configuration set to use for sending form submissions"
  value       = aws_sesv2_configuration_set.form_submissions.configuration_set_name
}

output "form_confirmations_configuration_set_name" {
  description = "The name of the configuration set to use for sending form confirmation emails"
  value       = aws_sesv2_configuration_set.form_confirmations.configuration_set_name
}

output "submission_email_bounces_and_complaints_queue_name" {
  value = module.submission_email_bounces_and_complaints_sqs.queue_name
}

output "submission_email_successful_deliveries_queue_name" {
  value = module.submission_email_successful_deliveries_sqs.queue_name
}

output "submission_email_bounces_and_complaints_dlq_name" {
  value = module.submission_email_bounces_and_complaints_sqs.dlq_name
}

output "confirmation_email_bounces_and_complaints_queue_name" {
  value = module.confirmation_email_bounces_and_complaints_sqs.queue_name
}

output "confirmation_email_bounces_and_complaints_dlq_name" {
  value = module.confirmation_email_bounces_and_complaints_sqs.dlq_name
}

output "auth0_email_bounces_and_complaints_queue_name" {
  value = module.auth0_bounces_and_complaints_sqs.queue_name
}

output "submission_email_bounces_and_complaints_kms_key_arn" {
  value = module.submission_email_bounces_and_complaints_sqs.kms_key_arn
}

output "submission_email_successful_deliveries_kms_key_arn" {
  value = module.submission_email_successful_deliveries_sqs.kms_key_arn
}

output "confirmation_email_bounces_and_complaints_kms_key_arn" {
  value = module.confirmation_email_bounces_and_complaints_sqs.kms_key_arn
}

output "test_mail_bucket_name" {
  value = module.test_mail_bucket.name
}
