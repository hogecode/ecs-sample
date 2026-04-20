# Root Module Outputs

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

# Subnets
output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_app_subnets" {
  description = "Private application layer subnet IDs"
  value       = module.vpc.private_app_subnets
}

output "private_api_subnets" {
  description = "Private API layer subnet IDs"
  value       = module.vpc.private_api_subnets
}

output "private_db_subnets" {
  description = "Private database layer subnet IDs"
  value       = module.vpc.private_db_subnets
}

# NAT Gateway
output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  description = "NAT Gateway public IPs"
  value       = module.vpc.nat_gateway_public_ips
}

# Internet Gateway
output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.internet_gateway_id
}

# VPC Endpoints
output "vpc_endpoints" {
  description = "VPC Endpoints IDs"
  value       = module.vpc.vpc_endpoints
}

# Security Groups
output "alb_public_security_group_id" {
  description = "Public ALB security group ID"
  value       = module.security_group.alb_public_security_group_id
}

output "nextjs_security_group_id" {
  description = "Next.js ECS security group ID"
  value       = module.security_group.nextjs_security_group_id
}

output "private_alb_security_group_id" {
  description = "Private ALB security group ID"
  value       = module.security_group.private_alb_security_group_id
}

output "go_server_security_group_id" {
  description = "Go Server ECS security group ID"
  value       = module.security_group.go_server_security_group_id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.security_group.rds_security_group_id
}

output "bastion_security_group_id" {
  description = "Bastion security group ID"
  value       = module.security_group.bastion_security_group_id
}

# Availability Zones
output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}

# Environment Info
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}
