# ========================================
# SSL Certificate (using terraform-aws-modules)
# ========================================

module "acm_certificate" {
  source = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name           = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method     = "DNS"
  zone_id               = var.route53_zone_id

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-cert"
  })
}

# ========================================
# VPN Server Certificate (using terraform-aws-modules)
# ========================================

module "acm_certificate_vpn" {
  source = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name       = "vpn.${var.domain_name}"
  validation_method = "DNS"
  zone_id           = var.route53_zone_id

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-vpn-server-cert"
  })
}
