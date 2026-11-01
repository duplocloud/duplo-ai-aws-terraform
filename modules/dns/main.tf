# Hosted zone is only looked up in route53 mode; external mode needs none.
data "aws_route53_zone" "this" {
  count        = var.create_route53_records ? 1 : 0
  name         = var.route53_zone_name
  private_zone = false
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.helpdesk_dns
  subject_alternative_names = [var.helpdesk_xterm_dns]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  validation_records = [
    for dvo in aws_acm_certificate.this.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

# Keyed by the (statically known) domain names so for_each is plannable before the
# certificate exists; record details are looked up from domain_validation_options.
resource "aws_route53_record" "cert_validation" {
  for_each = var.create_route53_records ? toset([var.helpdesk_dns, var.helpdesk_xterm_dns]) : toset([])

  allow_overwrite = true
  name            = [for dvo in aws_acm_certificate.this.domain_validation_options : dvo.resource_record_name if dvo.domain_name == each.key][0]
  records         = [[for dvo in aws_acm_certificate.this.domain_validation_options : dvo.resource_record_value if dvo.domain_name == each.key][0]]
  ttl             = 60
  type            = [for dvo in aws_acm_certificate.this.domain_validation_options : dvo.resource_record_type if dvo.domain_name == each.key][0]
  zone_id         = data.aws_route53_zone.this[0].zone_id
}

resource "aws_acm_certificate_validation" "this" {
  count                   = var.create_route53_records ? 1 : 0
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
