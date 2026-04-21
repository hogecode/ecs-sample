# ALB Module Outputs

# Public ALB
output "public_alb_id" {
  description = "ID of the public ALB"
  value       = aws_lb.public.id
}

output "public_alb_arn" {
  description = "ARN of the public ALB"
  value       = aws_lb.public.arn
}

output "public_alb_dns_name" {
  description = "DNS name of the public ALB"
  value       = aws_lb.public.dns_name
}

output "public_alb_zone_id" {
  description = "Zone ID of the public ALB"
  value       = aws_lb.public.zone_id
}

# Next.js Target Group
output "nextjs_target_group_arn" {
  description = "ARN of the Next.js target group"
  value       = aws_lb_target_group.nextjs.arn
}

output "nextjs_target_group_name" {
  description = "Name of the Next.js target group"
  value       = aws_lb_target_group.nextjs.name
}

# Private ALB
output "private_alb_id" {
  description = "ID of the private ALB"
  value       = aws_lb.private.id
}

output "private_alb_arn" {
  description = "ARN of the private ALB"
  value       = aws_lb.private.arn
}

output "private_alb_dns_name" {
  description = "DNS name of the private ALB"
  value       = aws_lb.private.dns_name
}

# Go Server Target Group
output "go_server_target_group_arn" {
  description = "ARN of the Go Server target group"
  value       = aws_lb_target_group.go_server.arn
}

output "go_server_target_group_name" {
  description = "Name of the Go Server target group"
  value       = aws_lb_target_group.go_server.name
}
