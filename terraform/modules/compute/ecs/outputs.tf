# ECS Module Outputs

output "nextjs_repository_url" {
  description = "ECR repository URL for Next.js"
  value       = aws_ecr_repository.nextjs.repository_url
}

output "go_server_repository_url" {
  description = "ECR repository URL for Go server"
  value       = aws_ecr_repository.go_server.repository_url
}

output "nextjs_log_group_name" {
  description = "CloudWatch Log Group name for Next.js"
  value       = aws_cloudwatch_log_group.nextjs.name
}

output "go_server_log_group_name" {
  description = "CloudWatch Log Group name for Go server"
  value       = aws_cloudwatch_log_group.go_server.name
}

output "ecs_cluster_id" {
  description = "ECS Cluster ID"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = module.ecs_cluster.cluster_arn
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_task_execution_role_arn" {
  description = "ECS Task Execution Role ARN"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_nextjs_arn" {
  description = "ECS Task Role ARN for Next.js"
  value       = aws_iam_role.ecs_task_role_nextjs.arn
}

output "ecs_task_role_go_server_arn" {
  description = "ECS Task Role ARN for Go Server"
  value       = aws_iam_role.ecs_task_role_go_server.arn
}
