# ========================================
# CI/CD Module Variables
# ========================================

variable "project_name" {
  description = "Project name"
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
  default     = "ap-northeast-1"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "hogecode"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "ecs-sample"
}

variable "github_branch_develop" {
  description = "Develop branch for staging deployment"
  type        = string
  default     = "develop"
}

variable "github_branch_main" {
  description = "Main branch for production deployment"
  type        = string
  default     = "main"
}

variable "github_token" {
  description = "GitHub OAuth token for CodePipeline"
  type        = string
  sensitive   = true
}

variable "ecr_nextjs_repository_name" {
  description = "ECR repository name for Next.js application"
  type        = string
  default     = "ecs-sample-nextjs"
}

variable "ecr_go_server_repository_name" {
  description = "ECR repository name for Go Server"
  type        = string
  default     = "ecs-sample-server"
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
}

variable "ecs_task_definition_family" {
  description = "ECS task definition family"
  type        = string
  default     = "ecs-sample"
}

variable "alb_target_group_arn" {
  description = "ALB target group ARN for load balancer configuration"
  type        = string
}

variable "codebuild_environment_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_MEDIUM"

  validation {
    condition     = contains(["BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM", "BUILD_GENERAL1_LARGE"], var.codebuild_environment_compute_type)
    error_message = "Compute type must be one of: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE"
  }
}

variable "codebuild_environment_image" {
  description = "CodeBuild environment image"
  type        = string
  default     = "aws/codebuild/standard:5.0"
}

variable "codebuild_privileged_mode" {
  description = "Whether to run CodeBuild in privileged mode (required for Docker builds)"
  type        = bool
  default     = true
}

variable "artifact_bucket_name" {
  description = "S3 bucket name for CodePipeline artifacts"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for artifact encryption"
  type        = string
  default     = ""
}

variable "enable_manual_approval" {
  description = "Enable manual approval for production deployment"
  type        = bool
  default     = true
}

variable "codedeploy_termination_wait_time_in_minutes" {
  description = "The number of minutes to wait before terminating Blue resources on the original instances during an in-place deployment"
  type        = number
  default     = 5
}

variable "codedeploy_deployment_ready_wait_time_in_minutes" {
  description = "The number of minutes before deployment terminates unhealthy instances in blue instances"
  type        = number
  default     = 0
}

variable "codedeploy_green_fleet_provisioning_option" {
  description = "Describe the instances to be used with the deployment"
  type        = string
  default     = "COPY_AUTO_SCALING_GROUP"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
