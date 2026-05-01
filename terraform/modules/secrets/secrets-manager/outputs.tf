# ========================================
# Secrets Manager Module Outputs
# ========================================

output "app_secrets_arn" {
  description = "Application secrets ARN"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "app_secrets_id" {
  description = "Application secrets ID"
  value       = aws_secretsmanager_secret.app_secrets.id
}

output "app_db_credentials_arn" {
  description = "Application database credentials secret ARN"
  value       = aws_secretsmanager_secret.app_db_credentials.arn
}

output "app_db_credentials_id" {
  description = "Application database credentials secret ID"
  value       = aws_secretsmanager_secret.app_db_credentials.id
}

output "rds_master_password_arn" {
  description = "RDS master password secret ARN"
  value       = aws_secretsmanager_secret.rds_master_password.arn
}

output "rds_master_password_id" {
  description = "RDS master password secret ID"
  value       = aws_secretsmanager_secret.rds_master_password.id
}

output "rds_master_username" {
  description = "RDS master username"
  value       = "admin"
  sensitive   = true
}

output "rds_master_password" {
  description = "RDS master password"
  value       = random_password.rds_master_password.result
  sensitive   = true
}

output "app_db_password" {
  description = "Application database password (use with caution)"
  value       = random_password.app_db_password.result
  sensitive   = true
}

output "db_read_only_password_arn" {
  description = "Read-only database password secret ARN"
  value       = aws_secretsmanager_secret.db_read_only_password.arn
}

output "db_read_only_password_id" {
  description = "Read-only database password secret ID"
  value       = aws_secretsmanager_secret.db_read_only_password.id
}

output "db_read_only_password" {
  description = "Read-only database password (use with caution)"
  value       = random_password.db_read_only_password.result
  sensitive   = true
}
