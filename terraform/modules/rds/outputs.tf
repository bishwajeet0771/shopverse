output "db_endpoint" {
  description = "RDS instance address (hostname, no port)"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "db_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "db_security_group_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.this.id
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB connection details"
  value       = aws_secretsmanager_secret.db.arn
}
