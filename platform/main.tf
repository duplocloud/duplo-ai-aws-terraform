data "aws_availability_zones" "available" {
  count = var.network.mode == "create" ? 1 : 0
  state = "available"
}

locals {
  create_network = var.network.mode == "create"
  create_cluster = var.cluster.mode == "create"
  create_efs     = var.efs.mode == "create"
  create_buckets = var.buckets.mode == "create"
  create_dns     = contains(["route53", "external"], var.dns.mode)

  cluster_name = try(var.cluster.values.cluster_name, "${var.deployment.name}-eks")

  # Resolved layer outputs: module output when created, else var.<layer>.provides.<name>
  vpc_id             = local.create_network ? module.vpc[0].vpc_id : try(var.network.provides.vpc_id, null)
  private_subnet_ids = local.create_network ? module.vpc[0].private_subnet_ids : try(var.network.provides.private_subnet_ids, null)
  public_subnet_ids  = local.create_network ? module.vpc[0].public_subnet_ids : try(var.network.provides.public_subnet_ids, null)

  eks_cluster_name       = local.create_cluster ? module.eks[0].cluster_name : try(var.cluster.provides.cluster_name, null)
  cluster_endpoint       = local.create_cluster ? module.eks[0].cluster_endpoint : try(var.cluster.provides.cluster_endpoint, null)
  cluster_ca_certificate = local.create_cluster ? module.eks[0].cluster_ca_certificate : try(var.cluster.provides.cluster_ca_certificate, null)
  oidc_provider_arn      = local.create_cluster ? module.eks[0].oidc_provider_arn : try(var.cluster.provides.oidc_provider_arn, null)
  oidc_provider_url      = local.create_cluster ? module.eks[0].oidc_provider_url : try(var.cluster.provides.oidc_provider_url, null)
  node_sg_id             = local.create_cluster ? module.eks[0].node_sg_id : try(var.cluster.provides.node_sg_id, null)
  # EKS-managed cluster security group (attached to all nodes)
  cluster_sg_id  = local.create_cluster ? module.eks[0].eks_cluster_sg_id : try(var.cluster.provides.cluster_sg_id, null)
  node_role_name = local.create_cluster ? module.eks[0].node_role_name : try(var.cluster.provides.node_role_name, null)

  # ALB security group (consumed by the app root's ingress annotations); "" when unknown
  alb_sg_id = local.create_cluster ? module.eks[0].alb_sg_id : try(var.cluster.provides.alb_sg_id, "")

  efs_id = local.create_efs ? module.efs[0].efs_id : try(var.efs.provides.efs_id, null)

  bucket_arn           = local.create_buckets ? module.s3[0].bucket_arn : try(var.buckets.provides.bucket_arn, null)
  userdata_bucket_arn  = local.create_buckets ? module.s3[0].userdata_bucket_arn : try(var.buckets.provides.userdata_bucket_arn, null)
  bucket_name          = local.create_buckets ? module.s3[0].bucket_name : try(var.buckets.provides.bucket_name, null)
  userdata_bucket_name = local.create_buckets ? module.s3[0].userdata_bucket_name : try(var.buckets.provides.userdata_bucket_name, null)

  certificate_arn                = local.create_dns ? module.dns[0].certificate_arn : try(var.dns.provides.certificate_arn, null)
  certificate_validation_records = local.create_dns ? module.dns[0].validation_records : try(var.dns.provides.certificate_validation_records, [])
  route53_zone_id                = local.create_dns ? module.dns[0].route53_zone_id : try(var.dns.provides.route53_zone_id, "")
}

module "vpc" {
  source = "../modules/vpc"
  count  = local.create_network ? 1 : 0

  cluster_name = local.cluster_name
  vpc_cidr     = try(var.network.values.vpc_cidr, null)
  azs          = slice(data.aws_availability_zones.available[0].names, 0, 3)
}

module "eks" {
  source = "../modules/eks"
  count  = local.create_cluster ? 1 : 0

  cluster_name          = local.cluster_name
  kubernetes_version    = try(var.cluster.values.kubernetes_version, null)
  vpc_id                = local.vpc_id
  private_subnet_ids    = local.private_subnet_ids
  node_instance_type    = try(var.cluster.values.node_instance_type, null)
  node_desired          = try(var.cluster.values.node_desired, null)
  node_min              = try(var.cluster.values.node_min, null)
  node_max              = try(var.cluster.values.node_max, null)
  node_disk_size        = try(var.cluster.values.node_disk_size, null)
  node_ami_type         = try(var.cluster.values.node_ami_type, null)
  additional_admin_arns = try(var.cluster.values.additional_admin_arns, null)

  endpoint_public_access          = try(var.cluster.values.endpoint_public_access, null)
  endpoint_public_access_cidrs    = try(var.cluster.values.endpoint_public_access_cidrs, null)
  node_role_web_identity_subjects = try(var.cluster.values.node_role_web_identity_subjects, null)
}

module "efs" {
  source = "../modules/efs"
  count  = local.create_efs ? 1 : 0

  cluster_name       = local.cluster_name
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
  node_sg_id         = local.node_sg_id
  eks_cluster_sg_id  = local.cluster_sg_id

  depends_on = [module.eks]
}

module "s3" {
  source = "../modules/s3"
  count  = local.create_buckets ? 1 : 0

  deployment_name           = var.deployment.name
  account_id                = var.deployment.account_id
  lifecycle_enabled         = try(var.buckets.values.lifecycle_enabled, null)
  lifecycle_expiration_days = try(var.buckets.values.lifecycle_expiration_days, null)
}

module "dns" {
  source = "../modules/dns"
  count  = local.create_dns ? 1 : 0

  helpdesk_dns           = var.deployment.host
  helpdesk_xterm_dns     = var.deployment.xterm_host
  create_route53_records = var.dns.mode == "route53"
  route53_zone_name      = try(var.dns.values.route53_zone_name, null)
}
