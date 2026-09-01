output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "db_endpoint" {
  description = "Full endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname only (no port) — use this for DB_HOST"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port (5432)"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "Security group attached to the RDS instance"
  value       = aws_security_group.rds.id
}
