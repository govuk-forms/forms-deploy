variable "env_name" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "Id of the VPC in which the database will be created"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet ids which should form the database's subnet group"
}

variable "ingress_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks from which ingress will be permitted"
}

variable "availability_zones" {
  type        = list(string)
  description = "The AZs to run the RDS cluster within"
  default     = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

variable "apply_immediately" {
  type        = bool
  description = "Whether to apply changes immediately or wait for maintenance period"
  default     = false
}

variable "backup_retention_period" {
  type        = number
  description = "How many days to keep db backups for"
  default     = 30
}

variable "auto_pause" {
  type        = bool
  description = "If true the cluster will pause when not in use"
  default     = false
}

variable "seconds_until_auto_pause" {
  type        = number
  description = "How long to wait until pauses the cluster due to inactivity"
  default     = 300
}

variable "max_capacity" {
  type        = number
  description = "The minimum Aurora Capacity Units to provision"
  default     = 2
}

variable "min_capacity" {
  type        = number
  description = "The maximum Aurora Capacity Units to provision"
  default     = 2
}

variable "rds_maintenance_window" {
  type        = string
  description = "When planned maintenance will take place such as minor and major version upgrades"
  default     = "wed:04:00-wed:04:30"
}

variable "identifier" {
  type        = string
  description = "The identifier or name of the cluster and its related parts"
}

variable "apps_list" {
  type = map(object({
    username = string
  }))
  description = "Map of apps and their database usernames for the cluster"
}

variable "database_identifier" {
  type        = string
  description = "The name of the database in the cluster"
}

variable "enable_advanced_database_insights" {
  type        = bool
  description = "Whether to enable Advanced Database Insights for the RDS instance"
  default     = false
}

variable "force_ssl_connections" {
  type        = bool
  description = "Whether to force SSL connections to the database"
  default     = true
}

variable "monitoring_interval" {
  type        = number
  description = "Interval, in seconds, between points when Enhanced Monitoring metrics are collected. A value of 0 means Enhanced Monitoring is disabled. Valid Values: 0, 1, 5, 10, 15, 30, 60. "
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Valid values for the monitoring interval in RDS Enhanced Monitoring are 0, 1, 5, 10, 15, 30 and 60"
  }
}

variable "monitoring_role_arn" {
  type        = string
  description = "ARN for the IAM role that allows RDS to send enhanced monitoring metrics to CloudWatch Logs. Only needed when the monitoring_interval is non zero"
  default     = ""
}
