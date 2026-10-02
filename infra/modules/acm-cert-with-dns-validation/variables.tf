variable "domain_name" {
  type        = string
  description = "The primary domain name for the certificate"
}

variable "zone_name" {
  type        = string
  description = "The Route53 hosted zone in which to create the validation records. Defaults to domain_name."
  default     = null
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Subject alternative names for the certificate. Must be within the same domain as domain_name"
}
