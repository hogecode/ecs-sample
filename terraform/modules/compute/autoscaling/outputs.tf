# ========================================
# Auto Scaling Module Outputs
# ========================================

output "autoscaling_group_name" {
  description = "Auto Scaling group name"
  value       = module.autoscaling.autoscaling_group_name
}

output "autoscaling_group_id" {
  description = "Auto Scaling group ID"
  value       = module.autoscaling.autoscaling_group_id
}

output "autoscaling_group_arn" {
  description = "Auto Scaling group ARN"
  value       = module.autoscaling.autoscaling_group_arn
}

output "autoscaling_group_desired_capacity" {
  description = "Desired capacity of Auto Scaling group"
  value       = module.autoscaling.autoscaling_group_desired_capacity
}

output "autoscaling_group_min_size" {
  description = "Minimum size of Auto Scaling group"
  value       = module.autoscaling.autoscaling_group_min_size
}

output "autoscaling_group_max_size" {
  description = "Maximum size of Auto Scaling group"
  value       = module.autoscaling.autoscaling_group_max_size
}

output "scale_up_policy_arn" {
  description = "Scale up policy ARN"
  value       = length(aws_autoscaling_policy.scale_up) > 0 ? aws_autoscaling_policy.scale_up[0].arn : null
}

output "scale_down_policy_arn" {
  description = "Scale down policy ARN"
  value       = length(aws_autoscaling_policy.scale_down) > 0 ? aws_autoscaling_policy.scale_down[0].arn : null
}
