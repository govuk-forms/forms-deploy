module "auth0_bounces_and_complaints_sqs" {
  source           = "./sqs"
  environment_name = var.environment_name
  environment_type = var.environment_type
  account_id       = local.account_id
  identifier       = "auth0_ses"
  policy_id        = "SESBouncesComplaintsQueueTopic"
  sqs_type         = "bounces_and_complaints"
}

module "submission_email_bounces_and_complaints_sqs" {
  source           = "./sqs"
  environment_name = var.environment_name
  environment_type = var.environment_type
  account_id       = local.account_id
  identifier       = "submission_email_ses"
  policy_id        = "SubmissionEmailSESBouncesComplaintsQueueTopic"
  sqs_type         = "bounces_and_complaints"
}

module "submission_email_successful_deliveries_sqs" {
  source           = "./sqs"
  environment_name = var.environment_name
  environment_type = var.environment_type
  account_id       = local.account_id
  identifier       = "submission_email_ses"
  policy_id        = "SubmissionEmailSESSuccessfulDeliveriesQueueTopic"
  sqs_type         = "successful_deliveries"
}

module "confirmation_email_bounces_and_complaints_sqs" {
  source           = "./sqs"
  environment_name = var.environment_name
  environment_type = var.environment_type
  account_id       = local.account_id
  identifier       = "confirmation_email_ses"
  policy_id        = "ConfirmationEmailSESBouncesComplaintsQueueTopic"
  sqs_type         = "bounces_and_complaints"
}
