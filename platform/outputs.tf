output "vpc_id" {
  description = "VPC ID (created, or adopted from network.provides)"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS cluster, worker nodes and EFS mount targets)"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs (the Helpdesk application load balancer)"
  value       = local.public_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = local.eks_cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = local.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded EKS cluster CA certificate"
  value       = local.cluster_ca_certificate
}

output "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider, used for IAM roles for service accounts (IRSA)"
  value       = local.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the cluster's OIDC issuer, without https://"
  value       = local.oidc_provider_url
}

output "node_sg_id" {
  description = "Security group ID attached to the worker nodes"
  value       = local.node_sg_id
}

output "cluster_sg_id" {
  description = "EKS-managed cluster security group ID (attached to the control plane and all nodes)"
  value       = local.cluster_sg_id
}

output "node_role_name" {
  description = "IAM role name of the worker nodes"
  value       = local.node_role_name
}

output "efs_id" {
  description = "EFS file system ID for Helpdesk file storage"
  value       = local.efs_id
}

output "bucket_arn" {
  description = "ARN of the app-data S3 bucket"
  value       = local.bucket_arn
}

output "userdata_bucket_arn" {
  description = "ARN of the user-data S3 bucket; null when an adopted buckets layer does not provide one"
  value       = local.userdata_bucket_arn
}

output "bucket_name" {
  description = "Name of the app-data S3 bucket"
  value       = local.bucket_name
}

output "userdata_bucket_name" {
  description = "Name of the user-data S3 bucket; null when an adopted buckets layer does not provide one"
  value       = local.userdata_bucket_name
}

output "certificate_arn" {
  description = "ACM certificate ARN for the Helpdesk hosts (pending validation in external mode until the records exist)"
  value       = local.certificate_arn
}

output "certificate_validation_records" {
  description = "DNS records (name, type, value) that validate the ACM certificate; create them yourself in external mode"
  value       = local.certificate_validation_records
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID; empty unless dns mode is route53"
  value       = local.route53_zone_id
}

output "alb_sg_id" {
  description = "ALB security group ID; empty when an adopted cluster does not provide one"
  value       = local.alb_sg_id
}

output "dns_mode" {
  description = "DNS layer mode: route53 | certificate | external"
  value       = var.dns.mode
}
