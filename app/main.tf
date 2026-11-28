data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = var.state.bucket
    key    = var.state.platform_key
    region = var.state.region
  }
}

locals {
  # Every platform output is read through try(): destroy must still plan when the platform state is
  # partial or gone (an interrupted platform apply, or platform destroyed first), so the app root
  # never blocks the platform's own destroy.
  platform_outputs = data.terraform_remote_state.platform.outputs
  platform = {
    vpc_id            = try(local.platform_outputs.vpc_id, "")
    public_subnet_ids = try(local.platform_outputs.public_subnet_ids, [])
    # A syntactically valid placeholder (the platform's default name) keeps provider validation happy.
    cluster_name           = try(local.platform_outputs.cluster_name, "${var.deployment.name}-eks")
    cluster_endpoint       = try(local.platform_outputs.cluster_endpoint, "")
    cluster_ca_certificate = try(local.platform_outputs.cluster_ca_certificate, "")
    oidc_provider_arn      = try(local.platform_outputs.oidc_provider_arn, "")
    oidc_provider_url      = try(local.platform_outputs.oidc_provider_url, "")
    alb_sg_id              = try(local.platform_outputs.alb_sg_id, null)
    node_role_name         = try(local.platform_outputs.node_role_name, "")
    efs_id                 = try(local.platform_outputs.efs_id, "")
    bucket_arn             = try(local.platform_outputs.bucket_arn, null)
    userdata_bucket_arn    = try(local.platform_outputs.userdata_bucket_arn, null)
    certificate_arn        = try(local.platform_outputs.certificate_arn, "")
    dns_mode               = try(local.platform_outputs.dns_mode, "")
  }

  create_addons = var.addons.mode == "create"

  # The node permissions policy goes only on a node role the platform root created; an adopted cluster's node
  # role is never modified. A platform state written before node_role_managed existed (v0.1.1 and earlier) falls
  # back to the name the eks module gives the role it creates.
  node_role_managed = try(tobool(local.platform_outputs.node_role_managed),
  local.platform.node_role_name == "${local.platform.cluster_name}-node-role")

  # dns mode is a platform output; only route53 mode runs external-dns.
  # Certificate validation is not awaited here: EKS tokens last ~15 minutes, so
  # the backend waits for the certificate to be ISSUED (ACM API) before planning app.
  dns_mode            = local.platform.dns_mode
  external_dns_active = local.dns_mode == "route53"

  # Adopted buckets may have no ARN (null or "")
  bucket_arn          = local.platform.bucket_arn == null ? "" : local.platform.bucket_arn
  userdata_bucket_arn = local.platform.userdata_bucket_arn == null ? "" : local.platform.userdata_bucket_arn
}

data "aws_eks_cluster_auth" "this" {
  name = local.platform.cluster_name
}

resource "random_password" "jwt_shared_secret" {
  length  = 48
  special = false
}

resource "random_password" "mongodb_root_password" {
  length  = 32
  special = false
}

module "addons" {
  source = "../modules/addons"
  count  = local.create_addons ? 1 : 0

  cluster_name            = local.platform.cluster_name
  oidc_provider_arn       = local.platform.oidc_provider_arn
  oidc_provider_url       = local.platform.oidc_provider_url
  vpc_id                  = local.platform.vpc_id
  efs_id                  = local.platform.efs_id
  node_role_name          = local.platform.node_role_name
  attach_node_permissions = local.node_role_managed
  s3_bucket_arn           = local.bucket_arn
  s3_userdata_bucket_arn  = local.userdata_bucket_arn

  external_dns_enabled         = local.external_dns_active
  external_dns_domain_filter   = try(var.addons.values.external_dns_domain_filter, null)
  alb_controller_chart_version = try(var.addons.values.alb_controller_chart_version, null)
  efs_csi_chart_version        = try(var.addons.values.efs_csi_chart_version, null)
  external_dns_chart_version   = try(var.addons.values.external_dns_chart_version, null)
}

module "helpdesk" {
  source = "../modules/helpdesk"

  cluster_name      = local.platform.cluster_name
  deployment_name   = var.deployment.name
  oidc_provider_arn = local.platform.oidc_provider_arn
  oidc_provider_url = local.platform.oidc_provider_url

  helpdesk_dns           = var.deployment.host
  helpdesk_xterm_dns     = var.deployment.xterm_host
  certificate_arn        = local.platform.certificate_arn
  alb_sg_id              = local.platform.alb_sg_id
  public_subnet_ids      = local.platform.public_subnet_ids
  vpc_id                 = local.platform.vpc_id
  s3_bucket_arn          = local.bucket_arn
  s3_userdata_bucket_arn = local.userdata_bucket_arn

  secrets               = var.secrets
  jwt_shared_secret     = random_password.jwt_shared_secret.result
  mongodb_root_password = random_password.mongodb_root_password.result

  release_name       = try(var.helpdesk.values.release_name, null)
  namespace          = try(var.helpdesk.values.namespace, null)
  chart_version      = try(var.helpdesk.values.chart_version, null)
  storage_class_name = try(var.helpdesk.values.storage_class_name, null)

  login_method        = try(var.helpdesk.values.login_method, null)
  local_admin_email   = try(var.helpdesk.values.local_admin_email, null)
  google_client_id    = try(var.helpdesk.values.google_client_id, null)
  microsoft_client_id = try(var.helpdesk.values.microsoft_client_id, null)
  microsoft_tenant_id = try(var.helpdesk.values.microsoft_tenant_id, null)
  auth_super_users    = try(var.helpdesk.values.auth_super_users, null)

  backend_image_tag                    = try(var.helpdesk.values.backend_image_tag, null)
  frontend_image_tag                   = try(var.helpdesk.values.frontend_image_tag, null)
  bedrock_subscription_enabled         = try(var.helpdesk.values.bedrock_subscription_enabled, null)
  helpdesk_analytics_collector_enabled = try(var.helpdesk.values.helpdesk_analytics_collector_enabled, null)
  helpdesk_mcp_enabled                 = try(var.helpdesk.values.helpdesk_mcp_enabled, null)
  installer_rbac_service_account_token = try(var.helpdesk.values.installer_rbac_service_account_token, null)
  installer_irsa_role_arn              = try(var.helpdesk.values.installer_irsa_role_arn, null)
  slack_backend_enabled                = try(var.helpdesk.values.slack_backend_enabled, null)
  slack_backend_image_tag              = try(var.helpdesk.values.slack_backend_image_tag, null)
  slack_helpdesk_default_agent         = try(var.helpdesk.values.slack_helpdesk_default_agent, null)
  slack_helpdesk_default_workspace     = try(var.helpdesk.values.slack_helpdesk_default_workspace, null)
  slack_app_portals                    = try(var.helpdesk.values.slack_app_portals, null)

  # The ALB controller, EFS CSI driver and storage classes must exist first.
  depends_on = [module.addons]
}
