# RDS Module Outputs

output "rds_instance_id" {
  description = "RDS Instance ID"
  value       = module.rds.db_instance_id
}

output "rds_instance_arn" {
  description = "RDS Instance ARN"
  value       = module.rds.db_instance_arn
}

output "rds_instance_endpoint" {
  description = "RDS Instance endpoint (hostname:port)"
  value       = module.rds.db_instance_endpoint
}

output "rds_instance_address" {
  description = "RDS Instance hostname"
  value       = module.rds.db_instance_address
}

output "rds_instance_port" {
  description = "RDS Instance port"
  value       = module.rds.db_instance_port
}

output "rds_instance_name" {
  description = "RDS Instance database name"
  value       = module.rds.db_instance_name
}

output "db_subnet_group_id" {
  description = "DB Subnet Group ID"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "DB Subnet Group ARN"
  value       = aws_db_subnet_group.main.arn
}

output "rds_connection_string" {
  description = "RDS connection string"
  value       = "mysql://${module.rds.db_instance_username}:@${module.rds.db_instance_address}:${module.rds.db_instance_port}/${module.rds.db_instance_name}"
  sensitive   = true
}
