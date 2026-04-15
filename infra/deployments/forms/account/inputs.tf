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

variable "environment_name" {
  description = "The name of the environment. This is distinct from the environment type, but is likely to share the same name in cases like production or staging."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.environment_name))
    error_message = "variable 'environment_name' must contain only alphanumeric characters, underscores, and hyphens; it must be a valid part of a DNS name"
  }
}

variable "environment_type" {
  type        = string
  description = "The type of environments the account will host."
  nullable    = false
  validation {
    condition     = contains(["development", "staging", "production", "user_research", "ithc"], var.environment_type)
    error_message = "variable 'environment_type' must be one of dev, staging, production, user_research, or ithc"
  }
}

variable "require_vpn_to_access" {
  type        = bool
  description = "Whether this AWS account will require users to be on the VPN to access it"
  nullable    = false
  default     = true
}

variable "apex_domain" {
  type        = string
  description = "The apex domain that will be hosted in the account. For example 'forms.service.gov.uk', 'staging.forms.service.gov.uk'"
  nullable    = false
}

variable "dns_delegation_records" {
  type        = map(list(string))
  description = <<EOF
Any DNS delegation records to set within the apex domain's zone. T
his is used to allow the account hosting 'forms.service.gov.uk' to delegate subdomains to other accounts

The value is a map of string => list(string)

{
  "staging.forms.service.gov.uk" = ["ns1", "ns2", "n3"]
  "dev.forms.service.gov.uk" = ["ns4", "ns5", "ns6", "ns7"]
}
EOF
  default     = {}
  nullable    = false
}

variable "codestar_connection_arn" {
  description = "It isn't possible to automate the creation of a CodeStar connection, so we must create it by hand once in each account and hardcode its ARN."
  type        = string
  nullable    = false
}

variable "deploy_account_id" {
  description = "the account number for deploy account"
  type        = string
  nullable    = false
}

variable "pentester_email_addresses" {
  description = "The email addresses for penetration testers carrying out IT Health Checks for us"
  type        = list(string)

  validation {
    condition     = var.environment_type != "production" && (length(var.pentester_email_addresses) >= 0) || var.environment_type == "production" && (length(var.pentester_email_addresses) < 1)
    error_message = "Penetration testing should not be taking place in a production environment"
  }
}

variable "pentester_cidr_ranges" {
  description = "The CIDR blocks from which penetration tester traffic can come"
  type        = list(string)

  validation {
    condition     = can([for cidr in var.pentester_cidr_ranges : cidrhost(cidr, 32)])
    error_message = "Each entry in the last must be a valid IPv4 CIDR range"
  }

  validation {
    condition     = var.environment_type != "production" && (length(var.pentester_cidr_ranges) >= 0) || var.environment_type == "production" && (length(var.pentester_cidr_ranges) < 1)
    error_message = "Penetration testing should not be taking place in a production environment"
  }
}
