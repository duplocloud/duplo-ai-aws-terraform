variable "deployment_name" {
  description = "Deployment name used to name the buckets"
  type        = string
}

variable "account_id" {
  description = "AWS account ID used to name the buckets"
  type        = string
}

variable "lifecycle_enabled" {
  description = "Enable S3 lifecycle rules"
  type        = bool
  default     = false
  nullable    = false
}

variable "lifecycle_expiration_days" {
  description = "Number of days after which objects expire"
  type        = number
  default     = 90
  nullable    = false
}
