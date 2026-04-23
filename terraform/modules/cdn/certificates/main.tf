# ========================================
# SSL Certificate (using terraform-aws-modules)
# ========================================

module "acm_certificate" {
  source = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name           = var.domain_name != "" ? var.domain_name : "example.com"
  subject_alternative_names = var.domain_name != "" ? ["*.${var.domain_name}"] : []
  validation_method     = "EMAIL"
  
  # Disable automatic validation - manual validation via Route53 will be done separately
  # when route53_zone_id is provided
  create_certificate   = true
  validate_certificate = false

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

  domain_name       = var.domain_name != "" ? "vpn.${var.domain_name}" : "vpn.example.com"
  validation_method = "EMAIL"
  
  # Disable automatic validation - Route53 validation can be done manually if needed
  create_certificate   = true
  validate_certificate = false

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-vpn-server-cert"
  })
}
