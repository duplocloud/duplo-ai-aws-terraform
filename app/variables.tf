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
# values: local_admin_email (required; sign-in is the local admin only), and
#   optional auth_super_users (comma-separated admin emails, super users along
#   with the local admin), chart_version, namespace, release_name, storage_class_name,
#   backend_image_tag, frontend_image_tag, slack_*, helpdesk_mcp_enabled,
#   helpdesk_analytics_collector_enabled, installer_irsa_role_arn,
#   installer_rbac_service_account_token
variable "helpdesk" {
  description = "DuploCloud AI layer (module helpdesk)"
  type        = any

  validation {
    condition     = try(var.helpdesk.mode, "") == "create"
    error_message = "helpdesk.mode must be \"create\"."
  }

  # Sign-in is the local admin only.
  validation {
    condition     = can(regex("^[^@\\s,]+@[^@\\s,]+\\.[^@\\s,]+$", trimspace(var.helpdesk.values.local_admin_email)))
    error_message = "Helpdesk needs helpdesk.values.local_admin_email, an email address (the admin who signs in first)."
  }

  # Google and Microsoft sign-in were removed: a deployment that used them must move to the local admin.
  validation {
    condition     = try(coalesce(var.helpdesk.values.login_method, "local"), "local") == "local"
    error_message = "Google and Microsoft sign-in are no longer supported. Remove helpdesk.values.login_method (and the OAuth client values), and set helpdesk.values.local_admin_email and secrets.local_admin_password; add other admins to helpdesk.values.auth_super_users."
  }

  validation {
    condition     = alltrue([for e in split(",", try(coalesce(var.helpdesk.values.auth_super_users, ""), "")) : can(regex("^[^@\\s,]+@[^@\\s,]+\\.[^@\\s,]+$", trimspace(e))) if trimspace(e) != ""])
    error_message = "helpdesk.values.auth_super_users must be a comma-separated list of email addresses."
  }
}

variable "secrets" {
  description = "User-entered secrets. Keys: licensing_token, local_admin_password, slack_app_token, slack_bot_token"
  type        = map(string)
  default     = {}
  sensitive   = true

  validation {
    condition     = length(lookup(var.secrets, "local_admin_password", "")) > 0
    error_message = "secrets.local_admin_password is required (the local admin's password)."
  }
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
