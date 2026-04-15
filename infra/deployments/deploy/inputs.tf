variable "deploy_account_id" {
  description = "the account number for deploy account"
  type        = string
  default     = "711966560482"
}

variable "codestar_connection_arn" {
  description = "the arn of the github connection to use"
  type        = string
  default     = "arn:aws:codeconnections:eu-west-2:711966560482:connection/c285479e-88b3-430e-8c59-d96035a30f53"
}

variable "send_logs_to_cyber" {
  description = "Whether logs should be sent to cyber"
  type        = bool
  default     = true
}

variable "drift_detection_schedule" {
  description = "EventBridge schedule expression for drift detection"
  type        = string
  default     = "cron(0 9 ? * MON *)"
}
