locals {
  # Sign-in is the local admin only, who is also the one super user.
  # Non-secret backend environment, rendered into the values document.
  extra_env = [{ name = "Authentication__LocalAdminEmail", value = var.local_admin_email }]

  rendered_values = templatefile("${path.module}/templates/values.yml.tftpl", {
    storage_class_name                         = var.storage_class_name
    helpdesk_dns                               = var.helpdesk_dns
    helpdesk_xterm_dns                         = var.helpdesk_xterm_dns
    infra_region                               = data.aws_region.current.name
    certificate_arn                            = var.certificate_arn
    alb_sg_id                                  = var.alb_sg_id
    public_subnet_ids                          = join(",", var.public_subnet_ids)
    local_admin_email                          = var.local_admin_email
    backend_extra_env                          = local.extra_env
    slack_backend_enabled                      = var.slack_backend_enabled
    slack_backend_image_tag                    = var.slack_backend_image_tag
    slack_helpdesk_default_agent               = var.slack_helpdesk_default_agent
    slack_helpdesk_default_workspace           = var.slack_helpdesk_default_workspace
    slack_app_portals                          = var.slack_app_portals
    bedrock_subscription_enabled               = var.bedrock_subscription_enabled
    bedrock_service_account_name               = var.bedrock_subscription_sa_name
    helpdesk_analytics_collector_enabled       = var.helpdesk_analytics_collector_enabled
    helpdesk_analytics_collector_irsa_role_arn = aws_iam_role.helpdesk_analytics_collector.arn
    helpdesk_backend_irsa_role_arn             = aws_iam_role.helpdesk_backend.arn
    helpdesk_agent_irsa_role_arn               = aws_iam_role.helpdesk_agent_bedrock.arn
    helpdesk_analytics_collector_app_instance  = var.deployment_name
    helpdesk_mcp_enabled                       = var.helpdesk_mcp_enabled
    installer_rbac_service_account_token       = var.installer_rbac_service_account_token
    installer_irsa_role_arn                    = var.installer_irsa_role_arn
    backend_image_tag                          = var.backend_image_tag
    frontend_image_tag                         = var.frontend_image_tag
  })

  # Secret values by key. Sensitive: only ever reach Helm through set_sensitive.
  secret_values = merge(
    { for k, v in var.secrets : k => v },
    {
      jwt_shared_secret     = var.jwt_shared_secret
      mongodb_root_password = var.mongodb_root_password
    }
  )

  # Whether a secret is present is not itself secret; this keeps the
  # set_sensitive for_each key set known and non-sensitive.
  secret_present = { for k in nonsensitive(keys(local.secret_values)) : k => nonsensitive(length(local.secret_values[k]) > 0) }

  # label: logical name (non-sensitive, shown in outputs); path: Helm value path; key: secret_values key.
  sensitive_candidates = [
    { label = "secrets.licensingToken", path = "secrets.licensingToken", key = "licensing_token", on = true },
    { label = "secrets.jwtSharedSecret", path = "secrets.jwtSharedSecret", key = "jwt_shared_secret", on = true },
    { label = "mongodb.auth.rootPassword", path = "mongodb.auth.rootPassword", key = "mongodb_root_password", on = true },
    {
      label = "backend.extraEnv.Authentication__LocalAdminPassword"
      path  = "backend.extraEnv[${length(local.extra_env)}].value"
      key   = "local_admin_password"
      on    = true
    },
    { label = "slackBackend.envFromSecret.data.SLACK_APP_TOKEN", path = "slackBackend.envFromSecret.data.SLACK_APP_TOKEN", key = "slack_app_token", on = var.slack_backend_enabled },
    { label = "slackBackend.envFromSecret.data.SLACK_BOT_TOKEN", path = "slackBackend.envFromSecret.data.SLACK_BOT_TOKEN", key = "slack_bot_token", on = var.slack_backend_enabled },
  ]

  sensitive_entries = [for c in local.sensitive_candidates : c if c.on && lookup(local.secret_present, c.key, false)]

}

data "aws_region" "current" {}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }

  lifecycle {
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_service_account_v1" "bedrock_subscription" {
  metadata {
    name      = var.bedrock_subscription_sa_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"     = aws_iam_role.bedrock_subscription.arn
      "meta.helm.sh/release-name"      = var.release_name
      "meta.helm.sh/release-namespace" = var.namespace
    }
  }

  depends_on = [kubernetes_namespace.this]
}

resource "helm_release" "helpdesk" {
  name       = var.release_name
  repository = "oci://quay.io/duplocloud"
  chart      = "helpdesk"
  version    = var.chart_version
  namespace  = var.namespace
  timeout    = 900

  values = [local.rendered_values]

  # The secret env var's name sits next to its sensitive value in extraEnv.
  set {
    name  = "backend.extraEnv[${length(local.extra_env)}].name"
    value = "Authentication__LocalAdminPassword"
  }

  # Helm's --set parser treats , \ { } specially, so they are backslash-escaped;
  # type "string" stops values like "true" or "123" being coerced.
  dynamic "set_sensitive" {
    for_each = local.sensitive_entries
    content {
      name  = set_sensitive.value.path
      value = replace(replace(replace(replace(local.secret_values[set_sensitive.value.key], "\\", "\\\\"), ",", "\\,"), "{", "\\{"), "}", "\\}")
      type  = "string"
    }
  }

  depends_on = [
    kubernetes_namespace.this,
    kubernetes_service_account_v1.bedrock_subscription
  ]
}

# The ALB is provisioned asynchronously by the load balancer controller, so
# the hostname can be empty on the first apply; a refresh picks it up.
data "kubernetes_ingress_v1" "helpdesk" {
  metadata {
    name      = var.release_name
    namespace = var.namespace
  }

  depends_on = [helm_release.helpdesk]
}
