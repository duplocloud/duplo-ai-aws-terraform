output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb.arn
}

output "efs_csi_role_arn" {
  description = "IAM role ARN for the EFS CSI Driver"
  value       = aws_iam_role.efs.arn
}

output "external_dns_enabled" {
  description = "Whether external-dns is installed"
  value       = var.external_dns_enabled
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS; empty when disabled"
  value       = try(aws_iam_role.external_dns[0].arn, "")
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI Driver"
  value       = aws_iam_role.ebs_csi.arn
}

output "storage_class_name" {
  description = "Kubernetes StorageClass name for EFS"
  value       = kubernetes_storage_class_v1.efs.metadata[0].name
}
