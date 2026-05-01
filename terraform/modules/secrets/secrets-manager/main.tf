# ========================================
# Random Password Generation
# ========================================

resource "random_password" "rds_master_password" {
  length            = 20
  special           = true
  override_special  = "!#$%&*()-_=+[]{}<>:?"
  min_lower         = 2
  min_numeric       = 2
  min_special       = 2
  min_upper         = 2
}

resource "random_password" "app_db_password" {
  length            = 20
  special           = true
  override_special  = "!#$%&*()-_=+[]{}<>:?"
  min_lower         = 2
  min_numeric       = 2
  min_special       = 2
  min_upper         = 2
}

resource "random_password" "db_read_only_password" {
  length            = 20
  special           = true
  override_special  = "!#$%&*()-_=+[]{}<>:?"
  min_lower         = 2
  min_numeric       = 2
  min_special       = 2
  min_upper         = 2
}

# ========================================
# RDS Master Password Secret
# ========================================

resource "aws_secretsmanager_secret" "rds_master_password" {
  name_prefix             = "${var.app_name}/rds/master-password-"
  description             = "RDS master password for ${var.app_name}-${var.environment}"
  kms_key_id              = var.secrets_kms_key_id # TODO: kmsモジュールを作成してKMSキーを管理する
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-rds-master-password"
  })
}

resource "aws_secretsmanager_secret_version" "rds_master_password" {
  secret_id       = aws_secretsmanager_secret.rds_master_password.id
  secret_string   = random_password.rds_master_password.result
}

# ========================================
# Application Database Credentials Secret
# ========================================

resource "aws_secretsmanager_secret" "app_db_credentials" {
  name_prefix             = "${var.app_name}/db/app-credentials-"
  description             = "Application database credentials for ${var.app_name}-${var.environment}"
  kms_key_id              = var.secrets_kms_key_id
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-app-db-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "app_db_credentials" {
  secret_id = aws_secretsmanager_secret.app_db_credentials.id
  secret_string = jsonencode({
    username = var.app_db_username
    password = random_password.rds_master_password.result
    host     = var.rds_endpoint
    database = var.rds_database_name
    port     = var.rds_port
    engine   = var.db_engine
  })
}

# ========================================
# Read-Only Database User Password Secret
# ========================================

resource "aws_secretsmanager_secret" "db_read_only_password" {
  name_prefix             = "${var.app_name}/db/readonly-password-"
  description             = "Read-only database user password for ${var.app_name}-${var.environment}"
  kms_key_id              = var.secrets_kms_key_id
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-db-readonly-password"
  })
}

resource "aws_secretsmanager_secret_version" "db_read_only_password" {
  secret_id       = aws_secretsmanager_secret.db_read_only_password.id
  secret_string   = random_password.db_read_only_password.result
}

# ========================================
# Application Secrets (combining all)
# ========================================

resource "aws_secretsmanager_secret" "app_secrets" {
  name_prefix             = "${var.app_name}/app-secrets-"
  description             = "Application secrets for ${var.app_name}-${var.environment}"
  kms_key_id              = var.secrets_kms_key_id
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-app-secrets"
  })
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    APP_KEY                   = var.app_key != "" ? var.app_key : random_password.rds_master_password.result
    DB_HOST                   = var.rds_endpoint
    DB_DATABASE               = var.rds_database_name
    DB_USERNAME               = var.app_db_username
    DB_PASSWORD               = random_password.app_db_password.result
    DB_READ_HOST              = var.rds_read_replica_endpoint != "" ? var.rds_read_replica_endpoint : var.rds_endpoint
    DB_READ_ONLY_USERNAME     = var.db_read_only_username
    DB_READ_ONLY_PASSWORD     = random_password.db_read_only_password.result
  })
}
