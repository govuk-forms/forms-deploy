variable "account_name" {
  type        = string
  description = "The name to be given to the account (e.g. dev, production)"
  nullable    = false
  validation {
    condition     = can(regex("^[A-Za-z-_]+$", var.account_name))
    error_message = "'account_name' may only contain alphabetic characters, dashes, and underscores"
  }
}

variable "aws_account_id" {
  type        = string
  description = "The AWS account ID for the account"
  nullable    = false
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS account IDs are exactly 12 digits long"
  }
}

variable "bucket" {
  description = "Name of the state file bucket. This is named to match the key in the S3 type backend"
  type        = string
  nullable    = false
}

variable "require_vpn_to_access" {
  type        = bool
  description = "Whether this AWS account will require users to be on the VPN to access it"
  nullable    = false
  default     = true
}

variable "deploy_account_id" {
  description = "the account number for deploy account"
  type        = string
  nullable    = false
}

variable "send_logs_to_cyber" {
  description = "Whether logs should be sent to cyber"
  type        = bool
}

variable "pentester_email_addresses" {
  description = "The email addresses for penetration testers carrying out IT Health Checks for us"
  type        = list(string)
}

variable "pentester_cidr_ranges" {
  description = "The CIDR blocks from which penetration tester traffic can come"
  type        = list(string)

  validation {
    condition     = can([for cidr in var.pentester_cidr_ranges : cidrhost(cidr, 0)])
    error_message = "Each entry in the list must be a valid CIDR range"
  }
}

variable "drift_detection_schedule" {
  description = "EventBridge schedule expression for drift detection"
  type        = string
  default     = "cron(0 9 ? * MON *)"
}
