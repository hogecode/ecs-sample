# ECS Module Variables

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# ========================================
# ECR Configuration
# ========================================

variable "ecr_nextjs_repository_name" {
  description = "ECR repository name for Next.js"
  type        = string
  default     = "ecs-nextjs"
}

variable "ecr_go_server_repository_name" {
  description = "ECR repository name for Go server"
  type        = string
  default     = "ecs-go-server"
}

variable "ecr_image_scan_on_push" {
  description = "Enable image scan on push"
  type        = bool
  default     = true
}

variable "ecr_image_tag_mutability" {
  description = "Image tag mutability"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "Must be MUTABLE or IMMUTABLE"
  }
}

# ========================================
# ECS Cluster Configuration
# ========================================

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_fargate_spot" {
  description = "Enable Fargate Spot instances"
  type        = bool
  default     = true
}

variable "capacity_provider_base_count" {
  description = "Base number of Fargate tasks"
  type        = number
  default     = 1
}

variable "capacity_provider_spot_weight" {
  description = "Weight for Fargate Spot in capacity provider strategy"
  type        = number
  default     = 50
}

# ========================================
# Logging Configuration
# ========================================

variable "logs_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}
