# Security Group Module - Using terraform-aws-modules

# ALB Public Security Group
module "alb_public_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-alb-public-sg-${var.environment}"
  description = "Security group for public ALB"
  vpc_id      = var.vpc_id

  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name = "${var.project_name}-alb-public-sg-${var.environment}"
  }
}

# Next.js ECS Security Group
module "nextjs_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-nextjs-sg-${var.environment}"
  description = "Security group for Next.js ECS tasks"
  vpc_id      = var.vpc_id

  ingress_rules            = ["http-3000-tcp"]
  ingress_with_source_security_group_id = [
    {
      rule                     = "http-3000-tcp"
      source_security_group_id = module.alb_public_sg.security_group_id
    }
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name = "${var.project_name}-nextjs-sg-${var.environment}"
  }
}

# Private ALB Security Group
module "private_alb_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-private-alb-sg-${var.environment}"
  description = "Security group for private ALB"
  vpc_id      = var.vpc_id

  ingress_rules            = ["http-8080-tcp"]
  ingress_with_source_security_group_id = [
    {
      rule                     = "http-8080-tcp"
      source_security_group_id = module.nextjs_sg.security_group_id
    }
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name = "${var.project_name}-private-alb-sg-${var.environment}"
  }
}

# Go Server ECS Security Group
module "go_server_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-go-server-sg-${var.environment}"
  description = "Security group for Go Server ECS tasks"
  vpc_id      = var.vpc_id

  ingress_rules            = ["http-8080-tcp"]
  ingress_with_source_security_group_id = [
    {
      rule                     = "http-8080-tcp"
      source_security_group_id = module.private_alb_sg.security_group_id
    }
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name = "${var.project_name}-go-server-sg-${var.environment}"
  }
}

# RDS Security Group
module "rds_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-rds-sg-${var.environment}"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  ingress_rules            = ["mysql-tcp", "postgresql-tcp"]
  ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.go_server_sg.security_group_id
    },
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.go_server_sg.security_group_id
    },
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.bastion_sg.security_group_id
    },
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.bastion_sg.security_group_id
    }
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name = "${var.project_name}-rds-sg-${var.environment}"
  }
}

# Bastion Security Group
module "bastion_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-bastion-sg-${var.environment}"
  description = "Security group for Bastion host"
  vpc_id      = var.vpc_id

  ingress_rules       = []
  egress_rules        = ["mysql-tcp", "postgresql-tcp", "https-443-tcp"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
  egress_ipv6_cidr_blocks = ["::/0"]

  tags = {
    Name = "${var.project_name}-bastion-sg-${var.environment}"
  }
}

# VPC Endpoints Security Group
module "vpc_endpoints_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-vpc-endpoints-sg-${var.environment}"
  description = "Security group for VPC Endpoints"
  vpc_id      = var.vpc_id

  ingress_rules       = ["https-443-tcp"]
  ingress_cidr_blocks = [var.vpc_cidr]

  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]

  tags = {
    Name = "${var.project_name}-vpc-endpoints-sg-${var.environment}"
  }
}

# Redis Security Group (for future use)
module "redis_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-redis-sg-${var.environment}"
  description = "Security group for Redis cache"
  vpc_id      = var.vpc_id

  ingress_rules            = ["redis-tcp"]
  ingress_with_source_security_group_id = [
    {
      rule                     = "redis-tcp"
      source_security_group_id = module.go_server_sg.security_group_id
    }
  ]

  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]

  tags = {
    Name = "${var.project_name}-redis-sg-${var.environment}"
  }
}
