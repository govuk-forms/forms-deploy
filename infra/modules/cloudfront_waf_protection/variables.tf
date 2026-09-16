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

variable "kinesis_subscription_role_arn" {
  description = "The arn of the role that is allowed to subscribe to the kinesis stream"
  type        = string
}

variable "anti_ddos_exempt_uri_regular_expressions" {
  description = "Regular expressions matching URIs that cannot handle the WAF Challenge action (e.g. API endpoints). Requests to these paths can only be blocked by the DDoSRequests rule, not challenged, during a DDoS event."
  type        = list(string)
  default     = ["^/up$"]
}
