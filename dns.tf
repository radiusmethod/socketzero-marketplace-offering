data "aws_route53_zone" "socketzero_app" {
  name         = var.aws_route53_zone
  private_zone = false
}

resource "aws_route53_record" "ami_socketzero_app" {
  zone_id = data.aws_route53_zone.socketzero_app.zone_id
  name    = "ami"
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.socketzero_receiver.dns_name]
}

resource "aws_acm_certificate" "ami_socketzero_app" {
  domain_name               = "ami.${var.aws_route53_zone}"
  validation_method         = "DNS"
  subject_alternative_names = ["ami.${var.aws_route53_zone}"]

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "ami_socketzero_app_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ami_socketzero_app.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.socketzero_app.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "ami_socketzero_app" {
  certificate_arn = aws_acm_certificate.ami_socketzero_app.arn
  validation_record_fqdns = [
    for record in aws_route53_record.ami_socketzero_app_validation : record.fqdn
  ]
}
