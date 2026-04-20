output "alb_public_security_group_id" {
  description = "Public ALB security group ID"
  value       = aws_security_group.alb_public.id
}

output "nextjs_security_group_id" {
  description = "Next.js ECS security group ID"
  value       = aws_security_group.nextjs.id
}

output "private_alb_security_group_id" {
  description = "Private ALB security group ID"
  value       = aws_security_group.private_alb.id
}

output "go_server_security_group_id" {
  description = "Go Server ECS security group ID"
  value       = aws_security_group.go_server.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "bastion_security_group_id" {
  description = "Bastion security group ID"
  value       = aws_security_group.bastion.id
}

output "redis_security_group_id" {
  description = "Redis security group ID"
  value       = aws_security_group.redis.id
}

output "vpc_endpoints_security_group_id" {
  description = "VPC Endpoints security group ID"
  value       = aws_security_group.vpc_endpoints.id
}
