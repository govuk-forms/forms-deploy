output "form_submissions_configuration_set_name" {
  description = "The name of the configuration set to use for sending form submissions"
  value       = module.ses.form_submissions_configuration_set_name
}

output "submission_email_bounces_and_complaints_dlq_name" {
  value = module.ses.submission_email_bounces_and_complaints_dlq_name
}

output "auth0_email_bounces_and_complaints_queue_name" {
  value = module.ses.auth0_email_bounces_and_complaints_queue_name
}

output "submission_email_bounces_and_complaints_kms_key_arn" {
  value = module.ses.submission_email_bounces_and_complaints_kms_key_arn
}

output "submission_email_successful_deliveries_kms_key_arn" {
  value = module.ses.submission_email_successful_deliveries_kms_key_arn
}

output "test_mail_bucket_name" {
  value = module.ses.test_mail_bucket_name
}
