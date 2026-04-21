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
  vpc_cidr     = module.vpc.vpc_cidr
}

# ========================================
# Phase 3: Application Load Balancer Configuration
# ========================================
module "alb" {
  source = "./modules/alb"

  project_name                    = var.project_name
  environment                     = var.environment
  vpc_id                          = module.vpc.vpc_id
  public_subnet_ids              = module.vpc.public_subnets
  private_api_subnet_ids         = module.vpc.private_api_subnets
  alb_public_security_group_id   = module.security_group.alb_public_security_group_id
  private_alb_security_group_id  = module.security_group.private_alb_security_group_id

  # HTTPS configuration (optional)
  enable_https       = var.enable_https
  alb_certificate_arn = var.alb_certificate_arn

  # Access logs (optional)
  enable_alb_access_logs = var.enable_alb_access_logs
  alb_access_logs_bucket = var.alb_access_logs_bucket

  depends_on = [module.security_group, module.vpc]
}

# ========================================
# Phase 4: ECS Configuration
# ========================================
module "ecs" {
  source = "./modules/ecs"

  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region

  # ECR Configuration
  ecr_nextjs_repository_name     = var.ecr_nextjs_repository_name
  ecr_go_server_repository_name  = var.ecr_go_server_repository_name
  ecr_image_scan_on_push         = var.ecr_image_scan_on_push
  ecr_image_tag_mutability       = var.ecr_image_tag_mutability

  # ECS Cluster Configuration
  enable_container_insights      = local.enable_container_insights
  enable_fargate_spot            = local.enable_fargate_spot
  capacity_provider_base_count   = local.capacity_provider_base_count
  capacity_provider_spot_weight  = local.capacity_provider_spot_weight

  # Logging Configuration
  logs_retention_days = local.logs_retention_days

  depends_on = [module.vpc, module.security_group]
}

# ========================================
# Phase 5: RDS Database Configuration
# ========================================
module "rds" {
  source = "./modules/rds"

  project_name              = var.project_name
  environment               = var.environment
  private_db_subnet_ids     = module.vpc.private_db_subnets
  rds_security_group_id     = module.security_group.rds_security_group_id

  # RDS Engine Configuration
  rds_engine                = var.rds_engine
  rds_engine_version        = var.rds_engine_version
  rds_instance_class        = local.rds_instance_class
  rds_allocated_storage     = var.rds_allocated_storage
  rds_database_name         = var.rds_database_name
  rds_username              = var.rds_username
  rds_password              = var.rds_password

  # High Availability
  rds_multi_az              = local.rds_multi_az
  rds_backup_retention_days = local.rds_backup_retention_days
  rds_publicly_accessible   = var.rds_publicly_accessible

  # Monitoring & Parameters
  rds_parameter_group_family = var.rds_parameter_group_family
  rds_parameters            = var.rds_parameters
  enable_enhanced_monitoring = var.enable_enhanced_monitoring

  depends_on = [module.vpc, module.security_group]
}
