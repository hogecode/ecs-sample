# ========================================
# Secrets Manager Module Variables
# ========================================

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_key" {
  description = "Application key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rds_endpoint" {
  description = "RDS endpoint"
  type        = string
  default     = ""
}

variable "rds_database_name" {
  description = "RDS database name"
  type        = string
  default     = ""
}

variable "app_db_username" {
  description = "Application database username"
  type        = string
  sensitive   = true
  default     = ""
}

variable "app_db_password" {
  description = "Application database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_access_key_id" {
  description = "AWS access key ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_secret_access_key" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rds_read_replica_endpoint" {
  description = "RDS read replica endpoint"
  type        = string
  default     = ""
}

variable "secrets_kms_key_id" {
  description = "KMS key ID for secrets encryption"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
