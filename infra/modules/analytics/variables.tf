variable "env_name" {
  type        = string
  description = "The name of the environment"
}

variable "firehose_buffering_interval_seconds" {
  type        = number
  description = "How long Firehose buffers records before committing them to the table"
  default     = 300
}
