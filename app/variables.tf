variable "deployment" {
  description = "Deployment identity: { name, region, host, xterm_host, account_id }"
  type = object({
    name       = string
    region     = string
    host       = string
    xterm_host = string
    account_id = string
  })
}

variable "state" {
  description = "Where the platform root's state lives: { bucket, region, platform_key }"
  type = object({
    bucket       = string
    region       = string
    platform_key = string
  })
}

# addons: { mode = "create" | "existing", values }
#   "create" installs the cluster add-ons and storage classes;
#   "existing" adopts them (module count = 0, nothing is modified).
# values (all optional): external_dns_domain_filter, alb_controller_chart_version,
#   efs_csi_chart_version, external_dns_chart_version
variable "addons" {
  description = "Cluster add-ons layer"
  type        = any

  validation {
    condition     = contains(["create", "existing"], try(var.addons.mode, ""))
    error_message = "addons.mode must be \"create\" or \"existing\"."
  }
}

# helpdesk: { mode = "create", values }
# values (all optional): login_method (local|google|microsoft, default local),
#   local_admin_email, google_client_id, microsoft_client_id, microsoft_tenant_id,
#   auth_super_users, chart_version, namespace, release_name, storage_class_name,
#   backend_image_tag, frontend_image_tag, slack_*, helpdesk_mcp_enabled,
#   helpdesk_analytics_collector_enabled, installer_irsa_role_arn,
#   installer_rbac_service_account_token
variable "helpdesk" {
  description = "Helpdesk layer"
  type        = any

  validation {
    condition     = try(var.helpdesk.mode, "") == "create"
    error_message = "helpdesk.mode must be \"create\"."
  }

  validation {
    condition     = contains(["local", "google", "microsoft"], try(var.helpdesk.values.login_method, "local"))
    error_message = "helpdesk.values.login_method must be one of: local, google, microsoft."
  }

  validation {
    condition     = try(var.helpdesk.values.login_method, "local") != "local" || length(try(var.helpdesk.values.local_admin_email, "")) > 0
    error_message = "helpdesk.values.local_admin_email is required for local login."
  }

  validation {
    condition     = try(var.helpdesk.values.login_method, "local") != "local" || length(lookup(var.secrets, "local_admin_password", "")) > 0
    error_message = "secrets.local_admin_password is required for local login."
  }
}

variable "secrets" {
  description = "User-entered secrets. Keys: licensing_token, local_admin_password, google_client_secret, microsoft_client_secret, slack_app_token, slack_bot_token"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
