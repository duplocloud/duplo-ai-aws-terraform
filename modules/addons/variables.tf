variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "efs_id" {
  description = "EFS filesystem ID used by the EFS storage class"
  type        = string
}

variable "node_role_name" {
  description = "IAM role name for EKS worker nodes (to attach the node permissions policy)"
  type        = string
}

variable "external_dns_enabled" {
  description = "Install external-dns (only useful when a Route53 zone is managed)"
  type        = bool
  default     = false
  nullable    = false
}

variable "external_dns_domain_filter" {
  description = "Domain filter for External DNS. Leave empty to manage all zones."
  type        = string
  default     = ""
  nullable    = false
}

variable "alb_controller_chart_version" {
  description = "Helm chart version for aws-load-balancer-controller"
  type        = string
  default     = "1.7.1"
  nullable    = false
}

variable "efs_csi_chart_version" {
  description = "Helm chart version for aws-efs-csi-driver"
  type        = string
  default     = "2.5.6"
  nullable    = false
}

variable "external_dns_chart_version" {
  description = "Helm chart version for external-dns"
  type        = string
  default     = "1.14.3"
  nullable    = false
}

variable "s3_bucket_arn" {
  description = "ARN of the main S3 bucket. Empty string disables the node role's S3 access statement."
  type        = string
  default     = ""
  nullable    = false
}

variable "s3_userdata_bucket_arn" {
  description = "ARN of the userdata S3 bucket. Empty string disables the node role's S3 access statement."
  type        = string
  default     = ""
  nullable    = false
}
