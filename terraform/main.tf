# ========================================
# Root Module - Infrastructure Orchestration
# VPC, SG, ACM, ALB, ECS, Bastion, S3, RDS,  CloudWatch, CI/CD, ElastiCache, Lambda, SES, SQS,
# ========================================
# TODO: cloudfrontも追加する


# Get current AWS account ID
data "aws_caller_identity" "current" {}

# ========================================
# Phase 1: VPC & Network Configuration
# ========================================
module "vpc" {
  source = "./modules/network/vpc"

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
  
  # Tags
  tags = local.common_tags
}


# ========================================
# Phase 2: Security Groups Configuration
# ========================================
module "security_group" {
  source = "./modules/network/security_group"

  # Basic configuration
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = module.vpc.vpc_cidr
}

# ========================================
# Phase 2: KMS Configuration
# ========================================
module "kms" {
  source = "./modules/security/kms"

  project_name            = var.project_name
  environment             = var.environment
  enable_kms_encryption   = var.enable_kms_encryption
  kms_deletion_window_days = var.kms_deletion_window_days
  common_tags             = local.common_tags

  depends_on = [module.security_group]
}

# ========================================
# Phase 2: Secrets Manager Configuration
# ========================================
module "secrets" {
  source = "./modules/secrets/secrets-manager"

  app_name                     = var.project_name
  environment                  = var.environment
  
  # RDS Configuration
  rds_endpoint                 = ""  # Will be updated after RDS creation
  rds_database_name            = var.rds_database_name
  rds_port                     = 3306
  db_engine                    = var.rds_engine
  
  # Database User Credentials
  app_db_username              = var.app_db_username != "" ? var.app_db_username : "appuser"
  db_read_only_username        = "readonly"
  
  # Optional: App Key (if needed)
  app_key                      = ""
  
  # KMS Encryption
  secrets_kms_key_id           = module.kms.secrets_manager_key_id
  
  # Tags
  common_tags                  = local.common_tags

  depends_on = [module.security_group, module.kms]
}


# ========================================
# Phase 3: SSL/TLS Certificates (ACM)
# ========================================
/*
module "certificates" {
  source = "./modules/cdn/certificates"

  app_name                  = var.project_name
  environment               = var.environment
  domain_name              = var.domain_name
  # TODO: zone_idを渡すのではなく、Route53のゾーンを作成して、そのゾーンIDを渡すようにする
  # data "aws_route53_zone" で取得するのが基本
  # あるいはzone_id = aws_route53_zone.this.zone_id
  route53_zone_id          = var.route53_zone_id
  common_tags              = local.common_tags

  depends_on = [module.vpc]
}
*/


# ========================================
# Phase 3: Application Load Balancer Configuration
# ========================================
# TODO: ALBでHTTPSを有効にする場合は、ACMで作成した証明書のARNを渡すようにする
module "alb" {
  source = "./modules/network/alb"

  project_name                    = var.project_name
  environment                     = var.environment
  vpc_id                          = module.vpc.vpc_id
  public_subnet_ids              = module.vpc.public_subnets
  private_api_subnet_ids         = module.vpc.private_api_subnets
  alb_public_security_group_id   = module.security_group.alb_public_security_group_id
  private_alb_security_group_id  = module.security_group.private_alb_security_group_id

  # HTTPS configuration (optional)
  enable_https       = var.enable_https
  # TODO: 現在は.tfvarsで直接ARNを渡しているが、ACMモジュールで作成した証明書のARNを渡すようにする
  alb_certificate_arn = var.alb_certificate_arn

  # Access logs (optional)
  enable_alb_access_logs = var.enable_alb_access_logs
  alb_access_logs_bucket = var.alb_access_logs_bucket

  depends_on = [module.security_group, module.vpc]
}


# ========================================
# Phase 4: ECR Configuration
# ========================================
module "ecr" {
  source = "./modules/compute/ecr"
  
  # ECR Configuration
  ecr_nextjs_repository_name     = var.ecr_nextjs_repository_name
  ecr_go_server_repository_name  = var.ecr_go_server_repository_name
  ecr_image_scan_on_push         = var.ecr_image_scan_on_push
  ecr_image_tag_mutability       = var.ecr_image_tag_mutability
}


# ========================================
# Phase 4: ECS Configuration
# ========================================
module "ecs" {
  source = "./modules/compute/ecs"

  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region

  # ECR Configuration
  ecr_nextjs_repository_name     = var.ecr_nextjs_repository_name
  ecr_go_server_repository_name  = var.ecr_go_server_repository_name
  ecr_nextjs_repository_url      = module.ecr.nextjs_repository_url
  ecr_go_server_repository_url   = module.ecr.go_server_repository_url
  ecr_image_scan_on_push         = var.ecr_image_scan_on_push
  ecr_image_tag_mutability       = var.ecr_image_tag_mutability

  # ECS Cluster Configuration
  enable_container_insights      = local.enable_container_insights
  enable_fargate_spot            = local.enable_fargate_spot
  capacity_provider_base_count   = local.capacity_provider_base_count
  capacity_provider_spot_weight  = local.capacity_provider_spot_weight

  # Logging Configuration
  logs_retention_days = local.logs_retention_days

  # Network Configuration
  private_app_subnet_ids    = module.vpc.private_app_subnets
  private_api_subnet_ids    = module.vpc.private_api_subnets
  nextjs_security_group_id  = module.security_group.nextjs_security_group_id
  go_server_security_group_id = module.security_group.go_server_security_group_id

  # Load Balancer Target Groups
  nextjs_target_group_arn   = module.alb.nextjs_target_group_arn
  go_server_target_group_arn = module.alb.go_server_target_group_arn

  depends_on = [module.vpc, module.security_group, module.alb, module.ecr]
}


# ========================================
# Phase 4: Bastion Fargate Configuration
# ========================================
module "bastion_fargate" {
  source = "./modules/compute/bastion-fargate"

  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  
  # Network Configuration
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_app_subnets
  bastion_security_group_id = module.security_group.bastion_security_group_id
  
  # ECS Configuration
  ecs_cluster_name = try(module.ecs.this_cluster_name, module.ecs.cluster_name, "")
  
  # Bastion Container Configuration
  bastion_image_uri = var.bastion_image_uri
  container_cpu     = var.bastion_container_cpu
  container_memory  = var.bastion_container_memory
  
  # Logging Configuration
  logs_retention_days = local.logs_retention_days
  
  # Database Configuration
  rds_endpoint                   = module.rds.rds_instance_endpoint
  rds_master_username            = var.rds_username
  rds_master_password_secret_arn = var.rds_master_password_secret_arn
  rds_database_name              = var.rds_database_name
  
  # Application Database Configuration
  app_db_username  = var.app_db_username
  app_db_password  = var.app_db_password
  db_read_only_password = var.db_read_only_password
  db_engine        = var.rds_engine
  
  # Tags
  tags = local.common_tags

  depends_on = [module.ecs, module.vpc, module.security_group]
}


# ========================================
# Phase 5: Storage (S3)
# ========================================
module "storage" {
  source = "./modules/storage/s3"

  app_name                   = var.project_name
  environment                = var.environment
  domain_name                = var.domain_name
  aws_region                 = var.aws_region
  s3_filesystem_kms_key_arn  = module.security_group.s3_filesystem_kms_key_arn
  caller_identity_account_id = data.aws_caller_identity.current.account_id
  common_tags                = local.common_tags
}


# ========================================
# Phase 6: RDS Database Configuration
# ========================================
module "rds" {
  source = "./modules/database/rds"

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


# ========================================
# Phase 6: ElastiCache (Redis) Configuration
# ========================================
#module "cache" {
#  source = "./modules/database/cache"
#
#  app_name              = var.project_name
#  environment           = var.environment
#  private_subnets      = module.vpc.private_app_subnets
#  redis_security_group_id = module.security_group.redis_security_group_id
#  redis_node_type      = "cache.t3.micro"
#  snapshot_retention_limit = 5
#  snapshot_window      = "03:00-05:00"
#  maintenance_window   = "sun:05:00-sun:06:00"
#  common_tags          = local.common_tags
#  depends_on = [module.vpc, module.security_group]
#}



# ========================================
# Phase 7: Monitoring & Logging
# ========================================
module "monitoring" {
  source = "./modules/monitoring/cloudwatch"

  app_name                     = var.project_name
  environment                  = var.environment
  cloudwatch_logs_kms_key_id   = var.enable_kms_encryption ? module.kms.cloudwatch_logs_key_id : var.cloudwatch_logs_kms_key_id
  cloudtrail_bucket_name       = var.cloudtrail_bucket_name
  common_tags                  = local.common_tags

  depends_on = [module.ecs, module.rds, module.alb, module.kms]
}


# ========================================
# Phase 8: CI/CD Pipeline Configuration
# ========================================
module "cicd" {
  source = "./modules/cicd"

  project_name             = var.project_name
  environment              = var.environment
  aws_region               = var.aws_region

  # GitHub Configuration
  github_owner             = "hogecode"
  github_repo              = "ecs-sample"
  github_token             = var.github_token
  github_branch_develop    = "develop"
  github_branch_main       = "main"

  # ECS Configuration
  ecs_cluster_name         = try(module.ecs.this_cluster_name, module.ecs.cluster_name, "")
  ecs_service_name         = try(module.ecs.this_service_name, module.ecs.service_name, "")
  ecs_task_definition_family = "ecs-sample"

  # ALB Configuration
  alb_target_group_arn     = try(module.alb.target_group_arn, "")
  alb_target_group_name    = try(module.alb.target_group_name, "")

  # Artifact Storage
  artifact_bucket_name     = module.storage.app_filesystem_bucket_name
  kms_key_id              = try(module.storage.artifact_bucket_kms_key_id, "")

  # CodeBuild Configuration
  codebuild_environment_compute_type = var.environment == "prod" ? "BUILD_GENERAL1_LARGE" : "BUILD_GENERAL1_MEDIUM"
  codebuild_environment_image        = "aws/codebuild/standard:5.0"
  codebuild_privileged_mode          = true

  # CodeDeploy Configuration
  enable_manual_approval   = var.environment == "prod" ? true : false

  # Tags
  common_tags              = local.common_tags

  depends_on = [module.ecs, module.alb, module.storage]
}


# ========================================
# Phase 9: Email Service (SES)
# ========================================
#
#module "email" {
#  source = "./modules/messaging/email"
#
#  app_name                     = var.project_name
#  environment                  = var.environment
#  domain_name                  = var.domain_name
#  route53_zone_id              = var.route53_zone_id
#  test_email_addresses         = var.test_email_addresses
#  test_email_domains           = var.test_email_domains
#  test_domain_route53_zone_id  = var.test_domain_route53_zone_id
#  common_tags                  = local.common_tags
#}



# ========================================
# Phase 9: Message Queue (SQS)
# ========================================
module "messaging" {
  source = "./modules/messaging/sqs"

  app_name           = var.project_name
  environment        = var.environment
  queue_names        = var.sqs_queue_names
  sqs_kms_key_arn    = try(module.storage.artifact_bucket_kms_key_id, "")
  common_tags        = local.common_tags
}



# ========================================
# Phase 10: Lambda Functions
# ========================================
module "s3_validation_lambda" {
  source = "./modules/lambda"

  lambda_function_name = "s3-file-validator"
  lambda_description   = "S3 file validation Lambda function - checks file size and MIME type"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  lambda_source_path   = "${path.module}/../lambda"

  # S3 trigger configuration
  enable_s3_trigger = var.enable_s3_validation_lambda
  s3_bucket_id      = try(module.storage.file_upload_bucket_id, "")
  s3_key_prefix     = "uploads/"
  s3_events         = ["s3:ObjectCreated:*"]

  # Lambda configuration
  lambda_timeout     = 60
  lambda_memory_size = 256

  # Environment variables
  environment_variables = {
    MAX_FILE_SIZE_MB = "10"
  }

  # CloudWatch logs
  logs_retention_days = local.logs_retention_days

  # Tags
  common_tags = local.common_tags

  depends_on = [module.storage]
}



