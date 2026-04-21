# ========================================
# SES Configuration (using terraform-aws-modules)
# ========================================

module "ses" {
  source = "terraform-aws-modules/ses/aws"
  version = "~> 1.0"

  domain_name           = var.domain_name
  zone_id               = var.route53_zone_id
  enable_dkim           = true
  enable_spf            = true
  verify_domain         = true

  configuration_set_name = "${var.app_name}-${var.environment}"
  
  tags = var.common_tags
}

# Test email addresses for sandbox mode (individual emails - fallback option)
resource "aws_ses_email_identity" "test_emails" {
  for_each = toset(var.test_email_addresses)
  email    = each.value
}

# Test email domains for sandbox mode (allows sending to any email at these domains)
resource "aws_ses_domain_identity" "test_domains" {
  count  = length(var.test_email_domains)
  domain = var.test_email_domains[count.index]
}

# DNS verification for test domains
resource "aws_route53_record" "test_domain_verification" {
  count   = length(var.test_email_domains) > 0 && var.test_domain_route53_zone_id != "" ? length(var.test_email_domains) : 0
  zone_id = var.test_domain_route53_zone_id
  name    = "_amazonses.${var.test_email_domains[count.index]}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.test_domains[count.index].verification_token]
}
