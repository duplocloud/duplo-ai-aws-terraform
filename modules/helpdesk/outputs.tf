output "release_name" {
  description = "Helm release name"
  value       = helm_release.helpdesk.name
}

output "release_status" {
  description = "Helm release status"
  value       = helm_release.helpdesk.status
}

output "load_balancer_hostname" {
  description = "ALB hostname from the ingress status; empty until the load balancer is provisioned"
  value       = try(data.kubernetes_ingress_v1.helpdesk.status[0].load_balancer[0].ingress[0].hostname, "")
}

output "rendered_values" {
  description = "Rendered Helm values document. Contains no secrets: those are passed as sensitive set values."
  value       = local.rendered_values
}

output "values_preview_keys" {
  description = "Non-sensitive preview of what is set: top-level values keys plus backend.extraEnv.<NAME> entries"
  value = concat(
    keys(yamldecode(local.rendered_values)),
    [for e in local.extra_env : "backend.extraEnv.${e.name}"],
    [for s in local.sensitive_entries : s.label if startswith(s.label, "backend.extraEnv.")]
  )
}

output "sensitive_value_labels" {
  description = "Labels (never values) of the secrets passed to Helm as sensitive set values"
  value       = [for s in local.sensitive_entries : s.label]
}

output "backend_irsa_role_arn" {
  description = "IAM role ARN for the helpdesk backend"
  value       = aws_iam_role.helpdesk_backend.arn
}

output "agent_irsa_role_arn" {
  description = "IAM role ARN for the helpdesk duplo-agent"
  value       = aws_iam_role.helpdesk_agent_bedrock.arn
}

output "bedrock_subscription_role_arn" {
  description = "IAM role ARN for the Bedrock subscription job"
  value       = aws_iam_role.bedrock_subscription.arn
}

output "analytics_collector_irsa_role_arn" {
  description = "IAM role ARN for the analytics collector"
  value       = aws_iam_role.helpdesk_analytics_collector.arn
}
