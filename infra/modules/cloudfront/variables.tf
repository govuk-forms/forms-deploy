variable "env_name" {
  type        = string
  description = "The name of the environment to be used in resource names."
}

variable "ip_rate_limit" {
  type        = number
  description = "The maximum number of permitted requests from an IP address in a 5 minute period"
  default     = 1000
}

variable "domain_name" {
  type        = string
  description = "The domain name for the distribution"
}

variable "alb_dns_name" {
  type        = string
  description = "The alb dns name to use as the origin of the distribution"
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Alternative names for the distribution and its certificate"
}

variable "nat_gateway_egress_ips" {
  type        = list(string)
  description = "The IP addresses of all the NAT gateways used for traffic to exit the GOV.UK Forms VPC"
}

variable "ips_to_block" {
  type        = list(string)
  description = "List of Origin IPs to block"
  default     = []
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

variable "serve_assets_from_s3" {
  description = "Whether to serve requests for /assets/* from the assets bucket rather than the applications. The deploy pipelines must have synced assets to the bucket before this is enabled."
  type        = bool
  default     = false
}
