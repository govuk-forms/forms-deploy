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

variable "alb_arn" {
  type        = string
  description = "ARN of the Application Load Balancer to be protected by AWS WAF"
}

variable "send_logs_to_cyber" {
  description = "Whether logs should be sent to cyber"
  type        = bool
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
