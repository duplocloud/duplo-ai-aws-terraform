output "certificate_arn" {
  description = "ACM certificate ARN (validated in route53 mode; pending validation in external mode)"
  value       = var.create_route53_records ? aws_acm_certificate_validation.this[0].certificate_arn : aws_acm_certificate.this.arn
}

output "validation_records" {
  description = "DNS validation records (name/type/value) for the certificate"
  value       = local.validation_records
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID; empty when not using Route53"
  value       = var.create_route53_records ? data.aws_route53_zone.this[0].zone_id : ""
}

output "route53_record_count" {
  description = "Number of aws_route53_record validation records created (0 in external mode)"
  value       = length(aws_route53_record.cert_validation)
}

output "validated" {
  description = "Whether Terraform validates the certificate itself (aws_acm_certificate_validation created)"
  value       = length(aws_acm_certificate_validation.this) > 0
}
