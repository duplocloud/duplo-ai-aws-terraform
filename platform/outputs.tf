output "vpc_id" {
  value = local.vpc_id
}

output "private_subnet_ids" {
  value = local.private_subnet_ids
}

output "public_subnet_ids" {
  value = local.public_subnet_ids
}

output "cluster_name" {
  value = local.eks_cluster_name
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}

output "cluster_ca_certificate" {
  value = local.cluster_ca_certificate
}

output "oidc_provider_arn" {
  value = local.oidc_provider_arn
}

output "oidc_provider_url" {
  value = local.oidc_provider_url
}

output "node_sg_id" {
  value = local.node_sg_id
}

output "cluster_sg_id" {
  value = local.cluster_sg_id
}

output "node_role_name" {
  value = local.node_role_name
}

output "efs_id" {
  value = local.efs_id
}

output "bucket_arn" {
  value = local.bucket_arn
}

output "userdata_bucket_arn" {
  value = local.userdata_bucket_arn
}

output "bucket_name" {
  value = local.bucket_name
}

output "userdata_bucket_name" {
  value = local.userdata_bucket_name
}

output "certificate_arn" {
  value = local.certificate_arn
}

output "certificate_validation_records" {
  value = local.certificate_validation_records
}

output "route53_zone_id" {
  value = local.route53_zone_id
}

output "alb_sg_id" {
  description = "ALB security group ID; empty when an adopted cluster does not provide one"
  value       = local.alb_sg_id
}

output "dns_mode" {
  description = "DNS layer mode: route53 | certificate | external"
  value       = var.dns.mode
}
