variable "root_domain" {
  description = "The root domain of the environment; Grafana is served at grafana.<root_domain>"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_cluster_arn" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_access_logs_bucket_name" {
  description = "The S3 bucket that receives ALB access logs. Its policy must permit the grafana/ prefix."
  type        = string
}

variable "kinesis_subscription_role_arn" {
  description = "The ARN of the role used by CloudWatch Logs to ship logs to Cribl/Splunk. Empty string disables shipping."
  type        = string
  default     = ""
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "image" {
  description = "The Grafana container image"
  type        = string
  default     = "docker.io/grafana/grafana:13.2.1"
}

variable "github_allowed_organizations" {
  description = "GitHub organisations whose members may sign in"
  type        = list(string)
}

variable "github_admin_team" {
  description = "GitHub team (org/team) whose members are Grafana server admins"
  type        = string
}

variable "github_editor_teams" {
  description = "GitHub teams (org/team) whose members are Grafana editors. Members of no listed team are denied."
  type        = list(string)
}

variable "seconds_until_auto_pause" {
  description = "How long the database must be idle before it pauses"
  type        = number
  default     = 3600
}

variable "rds_maintenance_window" {
  type = string
}
