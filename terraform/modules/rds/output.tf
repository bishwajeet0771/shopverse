output "db_instance_id" {
  description = "RDS PostgreSQL instance identifier"
  value       = aws_db_instance.this.id
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "PostgreSQL database name"
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "RDS PostgreSQL security group ID"
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "ARN of the RDS managed master-user secret"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
