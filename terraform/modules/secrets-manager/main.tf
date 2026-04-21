# ========================================
# Secrets Manager Module - Using terraform-aws-secrets-manager module
# ========================================

module "app_secrets" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name_prefix             = "${var.app_name}/"
  description             = "Application secrets for ${var.app_name}-${var.environment}"
  kms_key_id              = var.secrets_kms_key_id

  # Store secrets as a JSON object
  secret_string = jsonencode({
    APP_KEY                 = var.app_key
    DB_HOST                 = var.rds_endpoint
    DB_DATABASE             = var.rds_database_name
    DB_USERNAME             = var.app_db_username
    DB_PASSWORD             = var.app_db_password
    AWS_ACCESS_KEY_ID       = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY   = var.aws_secret_access_key
    DB_READ_HOST            = var.rds_read_replica_endpoint != "" ? var.rds_read_replica_endpoint : var.rds_endpoint
  })

  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-secrets"
  })
}

# ========================================
# Additional Secrets (if needed for specific services)
# ========================================

module "database_credentials" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name_prefix             = "${var.app_name}/db/"
  description             = "Database credentials for ${var.app_name}-${var.environment}"
  kms_key_id              = var.secrets_kms_key_id

  secret_string = jsonencode({
    username = var.app_db_username
    password = var.app_db_password
    host     = var.rds_endpoint
    database = var.rds_database_name
    port     = 5432
  })

  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-db-secrets"
  })
}

module "aws_credentials" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name_prefix             = "${var.app_name}/aws/"
  description             = "AWS credentials for ${var.app_name}-${var.environment}"
  kms_key_id              = var.secrets_kms_key_id

  secret_string = jsonencode({
    access_key_id     = var.aws_access_key_id
    secret_access_key = var.aws_secret_access_key
  })

  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-aws-secrets"
  })
}
