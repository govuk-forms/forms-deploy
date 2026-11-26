output "webhook_url" {
  description = "URL to set as the GitHub App's webhook URL. Null when the webhook is not enabled."
  value       = var.webhook_enabled ? aws_lambda_function_url.webhook[0].function_url : null
}
