# ========================================
# Secrets Manager Module Outputs
# ========================================

output "app_secrets_arn" {
  description = "Application secrets ARN"
  value       = module.app_secrets.secret_arn
}

output "app_secrets_id" {
  description = "Application secrets ID"
  value       = module.app_secrets.secret_id
}

output "database_credentials_arn" {
  description = "Database credentials secrets ARN"
  value       = module.database_credentials.secret_arn
}

output "database_credentials_id" {
  description = "Database credentials secrets ID"
  value       = module.database_credentials.secret_id
}

output "aws_credentials_arn" {
  description = "AWS credentials secrets ARN"
  value       = module.aws_credentials.secret_arn
}

output "aws_credentials_id" {
  description = "AWS credentials secrets ID"
  value       = module.aws_credentials.secret_id
}
