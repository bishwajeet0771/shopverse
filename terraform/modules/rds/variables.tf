variable "name" {
  description = "Prefix used for naming RDS resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to place the RDS instance in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "eks_node_sg_id" {
  description = "Security group ID of the EKS worker nodes, allowed to reach Postgres"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "shopverse"
}

variable "db_username" {
  description = "Master username"
  type        = string
  default     = "shopverse_admin"
}

variable "db_password" {
  description = "Master password - set this manually via -var, TF_VAR_db_password, or a CI secret. Never commit it."
  type        = string
  sensitive   = true
}

variable "engine_version" {
  description = "Postgres engine version"
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial storage size in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max storage size in GB for autoscaling (0 disables it)"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Whether to deploy a standby replica in another AZ"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip taking a final snapshot when the instance is destroyed"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental deletion of the RDS instance"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
