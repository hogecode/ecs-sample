# ========================================
# Bastion Fargate Module Outputs
# ========================================

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.bastion.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.bastion.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Logs group"
  value       = aws_cloudwatch_log_group.bastion.name
}

output "task_execution_role_arn" {
  description = "ARN of the task execution role"
  value       = aws_iam_role.bastion_task_execution_role.arn
}

output "task_role_arn" {
  description = "ARN of the task role"
  value       = aws_iam_role.bastion_task_role.arn
}

output "ssm_session_command" {
  description = "Command to start an SSM session to the bastion"
  value       = "aws ssm start-session --target ecs:${var.ecs_cluster_name}:${aws_ecs_service.bastion.name} --region ${var.aws_region}"
}
