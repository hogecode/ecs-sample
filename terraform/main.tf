# ========================================
# Root Module - Infrastructure Orchestration
# ========================================

# ========================================
# Phase 1: VPC & Network Configuration
# ========================================
module "vpc" {
  source = "./modules/vpc"

  # Basic configuration
  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  
  # Network CIDR configuration
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_api_subnet_cidrs  = var.private_api_subnet_cidrs
  private_db_subnet_cidrs   = var.private_db_subnet_cidrs
  
  # NAT Gateway & Flow Logs (auto-configured by environment)
  enable_nat_gateway        = var.enable_nat_gateway
  nat_gateway_count         = local.nat_gateway_count
  enable_vpc_flow_logs      = local.enable_vpc_flow_logs
  
  # This will be updated after security_group is created
  vpc_endpoints_security_group_id = module.security_group.vpc_endpoints_security_group_id
  
  # Tags
  tags = local.common_tags

  # Ensure security_group is created first
  depends_on = [module.security_group]
}

# ========================================
# Phase 2: Security Groups Configuration
# ========================================
module "security_group" {
  source = "./modules/security_group"

  # Basic configuration
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  # Tags
  tags = local.common_tags
}

# ALB Module (coming in phase 3)
# module "alb" {
#   source = "./modules/alb"
# 
#   project_name = var.project_name
#   environment  = var.environment
#   vpc_id       = module.vpc.vpc_id
#   # ... other configurations
# }

# ECS Module (coming in phase 4)
# module "ecs" {
#   source = "./modules/ecs"
# 
#   project_name = var.project_name
#   environment  = var.environment
#   # ... other configurations
# }

# RDS Module (coming in phase 5)
# module "rds" {
#   source = "./modules/rds"
# 
#   project_name = var.project_name
#   environment  = var.environment
#   # ... other configurations
# }
