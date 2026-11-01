variable "helpdesk_dns" {
  description = "Primary DNS name for the helpdesk (e.g. ai.example.com)"
  type        = string
}

variable "helpdesk_xterm_dns" {
  description = "DNS name for the helpdesk xterm service"
  type        = string
}

variable "create_route53_records" {
  description = "true: validate the certificate via Route53 records in route53_zone_name. false: create the certificate only and emit validation_records for the customer to create."
  type        = bool
  default     = true
  nullable    = false
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name (e.g. example.com). Required when create_route53_records = true."
  type        = string
  default     = ""
  nullable    = false
}
