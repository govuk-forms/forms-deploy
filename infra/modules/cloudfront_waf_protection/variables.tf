variable "environment_name" {
  description = "The name of the environment. This is distinct from the environment type, but is likely to share the same name in cases like production or staging."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.environment_name))
    error_message = "variable 'environment_name' must contain only alphanumeric characters, underscores, and hyphens; it must be a valid part of a DNS name"
  }
}

variable "ips_to_block" {
  type        = list(string)
  description = "List of Origin IPs to block"
  default     = []
}

variable "ip_rate_limit" {
  type        = number
  description = "The maximum number of permitted requests from an IP address in a 5 minute period"
  default     = 1000
}

variable "nat_gateway_egress_ips" {
  type        = list(string)
  description = "The IP addresses of all the NAT gateways used for traffic to exit the GOV.UK Forms VPC"
}

variable "send_logs_to_cyber" {
  description = "Whether logs should be sent to cyber"
  type        = bool
}

variable "rate_limit_bypass_cidrs" {
  description = "CIDR blocks that should be able to bypass rate limiting. This is used to allow penetration testers to carry out the type of tests that would otherwise get them rate limited."
  type        = list(string)
  default     = []
}

variable "file_upload_max_size" {
  description = "The maximum file size allowed for uploads in bytes. This should be larger than the maximum file size defined in the form schema, so that people can get the pretty error message from the form rather than a WAF error."
  type        = number
  default     = 100 * 1024 * 1024 # 100 MB
}

variable "bulk_options_max_size" {
  description = "The maximum file size allowed for bulk options uploads in bytes."
  # The default is based on allowing 1000 options, 100 characters each, plus some overhead for the rest of the form data (400 bytes).
  # 400 + (max_count_inputs * max_length_per_input) + (max_count_inputs * 6)
  # the 6 is for the urlencoded `\r\n` at the end of each line
  type    = number
  default = 400 + (1000 * 100) + (1000 * 6) # 106400 bytes (103.91 KB)
}

variable "standard_form_response_body_max_size" {
  description = "The default maximum size allowed for each form response body in bytes (ie. all response fields except file uploads). This should be larger than the maximum size defined in the form schema, so that people can get the pretty error message from the form rather than a WAF error."
  type        = number
  default     = 100 * 1024 # 100 KB
}

variable "admin_extended_post_body_max_size" {
  description = "The maximum request body size allowed for admin endpoints that require larger payloads than standard operations"
  type        = number
  default     = 500 * 1024 # 500 KB
}

variable "kinesis_subscription_role_arn" {
  description = "The arn of the role that is allowed to subscribe to the kinesis stream"
  type        = string
}

variable "anti_ddos_exempt_uri_regular_expressions" {
  description = "Regular expressions matching URIs that cannot handle the WAF Challenge action (e.g. API endpoints). Requests to these paths can only be blocked by the DDoSRequests rule, not challenged, during a DDoS event."
  type        = list(string)
  default     = ["^/up$"]
}
