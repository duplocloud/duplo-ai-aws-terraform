variable "cluster_name" {
  description = "EKS cluster name (prefix for IAM resources)"
  type        = string
}

variable "deployment_name" {
  description = "Deployment name; used as the analytics collector app instance"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the cluster's OIDC provider (without https://)"
  type        = string
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "duplo-ai-helpdesk"
  nullable    = false
}

variable "namespace" {
  description = "Kubernetes namespace for the release"
  type        = string
  default     = "helpdesk"
  nullable    = false
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "0.2.24"
  nullable    = false
}

variable "storage_class_name" {
  description = "Kubernetes StorageClass name for EFS (used by backend and duploAgent)"
  type        = string
  default     = "ai-studio-efs"
  nullable    = false
}

variable "helpdesk_dns" {
  description = "DuploCloud AI DNS hostname (e.g. duplo-ai.example.com)"
  type        = string
}

variable "helpdesk_xterm_dns" {
  description = "DuploCloud AI xterm DNS hostname"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the ALB"
  type        = string
}

variable "alb_sg_id" {
  description = "ALB security group ID. Empty string lets the load balancer controller manage its own."
  type        = string
  default     = ""
  nullable    = false
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "s3_bucket_arn" {
  description = "ARN of the main S3 bucket. Empty string omits the bucket statement from the backend role."
  type        = string
  default     = ""
  nullable    = false
}

variable "s3_userdata_bucket_arn" {
  description = "ARN of the userdata S3 bucket. Empty string omits the bucket statement from the backend role."
  type        = string
  default     = ""
  nullable    = false
}

# ── Authentication ────────────────────────────────────────────────────────────
# Sign-in is the local admin only (no Google or Microsoft sign-in).
variable "local_admin_email" {
  description = "Email of the local admin, who signs in with secrets.local_admin_password; always a super user"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[^@\\s,]+@[^@\\s,]+\\.[^@\\s,]+$", var.local_admin_email))
    error_message = "local_admin_email must be an email address."
  }
}

variable "auth_super_users" {
  description = "Comma-separated admin emails made Helpdesk super users in addition to local_admin_email"
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = alltrue([for e in split(",", var.auth_super_users) : can(regex("^[^@\\s,]+@[^@\\s,]+\\.[^@\\s,]+$", trimspace(e))) if trimspace(e) != ""])
    error_message = "auth_super_users must be a comma-separated list of email addresses."
  }
}

# ── Secrets (never rendered into the values document) ────────────────────────
variable "secrets" {
  description = "User-entered secrets: licensing_token, local_admin_password, slack_app_token, slack_bot_token"
  type        = map(string)
  default     = {}
  nullable    = false
  sensitive   = true

  validation {
    condition     = length(lookup(var.secrets, "local_admin_password", "")) > 0
    error_message = "secrets.local_admin_password is required (the local admin's password)."
  }
}

variable "jwt_shared_secret" {
  description = "JWT shared secret"
  type        = string
  sensitive   = true
}

variable "mongodb_root_password" {
  description = "MongoDB root password"
  type        = string
  sensitive   = true
}

# ── Features ──────────────────────────────────────────────────────────────────
variable "bedrock_subscription_enabled" {
  description = "Enable Bedrock subscription hook job"
  type        = bool
  default     = true
  nullable    = false
}

variable "bedrock_subscription_namespace" {
  description = "Namespace of the Bedrock subscription service account"
  type        = string
  default     = "helpdesk"
  nullable    = false
}

variable "bedrock_subscription_sa_name" {
  description = "Service account name used by the Bedrock subscription job"
  type        = string
  default     = "duplo-ai-helpdesk-bedrock-subscription"
  nullable    = false
}

variable "helpdesk_backend_sa_namespace" {
  description = "Namespace of the helpdesk backend service account"
  type        = string
  default     = "helpdesk"
  nullable    = false
}

variable "helpdesk_backend_sa_name" {
  description = "Service account name of the helpdesk backend pod"
  type        = string
  default     = "duplo-ai-helpdesk-backend"
  nullable    = false
}

variable "helpdesk_agent_sa_namespace" {
  description = "Namespace of the helpdesk duplo-agent service account"
  type        = string
  default     = "helpdesk"
  nullable    = false
}

variable "helpdesk_agent_sa_name" {
  description = "Service account name of the helpdesk duplo-agent pod"
  type        = string
  default     = "duplo-ai-helpdesk-duplo-agent"
  nullable    = false
}

variable "helpdesk_analytics_collector_sa_namespace" {
  description = "Namespace of the analytics collector service account"
  type        = string
  default     = "helpdesk"
  nullable    = false
}

variable "helpdesk_analytics_collector_sa_name" {
  description = "Service account name of the analytics collector pod"
  type        = string
  default     = "duplo-ai-helpdesk-collector"
  nullable    = false
}

variable "helpdesk_analytics_collector_enabled" {
  description = "Run the analytics collector, which reports usage to the DuploCloud control plane"
  type        = bool
  default     = true
  nullable    = false
}

variable "helpdesk_mcp_enabled" {
  description = "Enable the helpdesk-mcp deployment"
  type        = bool
  default     = true
  nullable    = false
}

variable "installer_rbac_service_account_token" {
  description = "installer.rbac.serviceAccountToken in the chart"
  type        = bool
  default     = false
  nullable    = false
}

variable "installer_irsa_role_arn" {
  description = "IAM role ARN for the installer's ServiceAccount. Empty string omits the annotation."
  type        = string
  default     = ""
  nullable    = false
}

variable "backend_image_tag" {
  description = "Override for backend.image.tag. Empty string uses the chart default."
  type        = string
  default     = ""
  nullable    = false
}

variable "frontend_image_tag" {
  description = "Override for frontend.image.tag. Empty string uses the chart default."
  type        = string
  default     = ""
  nullable    = false
}

# ── Slack backend ─────────────────────────────────────────────────────────────
variable "slack_backend_enabled" {
  description = "Enable the Slack backend"
  type        = bool
  default     = false
  nullable    = false
}

variable "slack_backend_image_tag" {
  description = "Slack backend image tag"
  type        = string
  default     = ""
  nullable    = false
}

variable "slack_helpdesk_default_agent" {
  description = "Default agent for Slack helpdesk"
  type        = string
  default     = ""
  nullable    = false
}

variable "slack_helpdesk_default_workspace" {
  description = "Default workspace for Slack helpdesk"
  type        = string
  default     = ""
  nullable    = false
}

variable "slack_app_portals" {
  description = "Slack app portals JSON config"
  type        = string
  default     = ""
  nullable    = false
}
