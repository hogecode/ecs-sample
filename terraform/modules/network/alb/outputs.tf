# ========================================
# ALB Module Outputs
# ========================================

output "public_alb_id" {
  description = "Public ALB ID"
  value       = try(module.public_alb.this_lb_id, module.public_alb.lb_id, "")
}

output "public_alb_arn" {
  description = "Public ALB ARN"
  value       = try(module.public_alb.this_lb_arn, module.public_alb.lb_arn, "")
}

output "public_alb_dns_name" {
  description = "Public ALB DNS name"
  value       = try(module.public_alb.this_lb_dns_name, module.public_alb.lb_dns_name, "")
}

output "public_alb_zone_id" {
  description = "Public ALB Zone ID"
  value       = try(module.public_alb.this_lb_zone_id, module.public_alb.lb_zone_id, "")
}

output "nextjs_target_group_arn" {
  description = "Next.js target group ARN"
  value       = try(module.public_alb.this_target_group_arns["nextjs"], module.public_alb.target_group_arns["nextjs"], "")
}

output "nextjs_target_group_name" {
  description = "Next.js target group name"
  value       = try(module.public_alb.this_target_group_names["nextjs"], module.public_alb.target_group_names["nextjs"], "")
}

output "target_group_arn" {
  description = "Target group ARN (alias for nextjs_target_group_arn)"
  value       = try(module.public_alb.this_target_group_arns["nextjs"], module.public_alb.target_group_arns["nextjs"], "")
}

output "private_alb_id" {
  description = "Private ALB ID"
  value       = try(module.private_alb.this_lb_id, module.private_alb.lb_id, "")
}

output "private_alb_arn" {
  description = "Private ALB ARN"
  value       = try(module.private_alb.this_lb_arn, module.private_alb.lb_arn, "")
}

output "private_alb_dns_name" {
  description = "Private ALB DNS name"
  value       = try(module.private_alb.this_lb_dns_name, module.private_alb.lb_dns_name, "")
}

output "private_alb_zone_id" {
  description = "Private ALB Zone ID"
  value       = try(module.private_alb.this_lb_zone_id, module.private_alb.lb_zone_id, "")
}

output "go_server_target_group_arn" {
  description = "Go Server target group ARN"
  value       = try(module.private_alb.target_group_arns["go-server"], "")
}

output "go_server_target_group_name" {
  description = "Go Server target group name"
  value       = try(module.private_alb.target_group_names["go-server"], "")
}
