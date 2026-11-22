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
variable "login_method" {
  description = "First-login method: local (admin email + password), google, or microsoft"
  type        = string
  default     = "local"
  nullable    = false

  validation {
    condition     = contains(["local", "google", "microsoft"], var.login_method)
    error_message = "login_method must be one of: local, google, microsoft."
  }
}

variable "local_admin_email" {
  description = "Admin email for local login (also added to auth super users)"
  type        = string
  default     = ""
  nullable    = false
}

variable "google_client_id" {
  description = "Google OAuth client ID (login_method = google)"
  type        = string
  default     = ""
  nullable    = false
}

variable "microsoft_client_id" {
  description = "Microsoft (Entra) OAuth client ID (login_method = microsoft)"
  type        = string
  default     = ""
  nullable    = false
}

variable "microsoft_tenant_id" {
  description = "Microsoft (Entra) tenant ID, e.g. \"common\" or a GUID (login_method = microsoft)"
  type        = string
  default     = ""
  nullable    = false
}

variable "auth_super_users" {
  description = "Comma-separated list of super user emails"
  type        = string
  default     = ""
  nullable    = false
}

# ── Secrets (never rendered into the values document) ────────────────────────
variable "secrets" {
  description = "User-entered secrets: licensing_token, local_admin_password, google_client_secret, microsoft_client_secret, slack_app_token, slack_bot_token"
  type        = map(string)
  default     = {}
  nullable    = false
  sensitive   = true
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
  description = "Enable the analytics collector deployment"
  type        = bool
  default     = false
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
