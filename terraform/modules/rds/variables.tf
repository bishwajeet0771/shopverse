variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to launch RDS in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (must span 2+ AZs)"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to reach Postgres on port 5432 (typically the EKS node/cluster SG)"
  type        = list(string)
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "shopverse"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "shopverse"
}

variable "db_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "Postgres engine version"
  type        = string
  default     = "16.4"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling in GB"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Whether to deploy a standby replica in a second AZ (recommended for production; note this changes instance cost, not the class itself)"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Prevent accidental deletion of the DB instance"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (keep false for production)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
