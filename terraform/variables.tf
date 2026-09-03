# ──────────────────────────────────────────────
# General
# ──────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "shopverse"
}

# ──────────────────────────────────────────────
# VPC
# ──────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ──────────────────────────────────────────────
# EKS
# ──────────────────────────────────────────────
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "shopverse-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

# ──────────────────────────────────────────────
# RDS (Postgres)
# ──────────────────────────────────────────────
variable "db_name" {
  description = "Initial Postgres database name"
  type        = string
  default     = "shopverse"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "shopverse"
}

variable "db_password" {
  description = "Master password for RDS (pass via TF_VAR_db_password / CI secret, never commit)"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ standby for RDS (recommended for production HA)"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Prevent accidental deletion of the RDS instance (recommended: true for production)"
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Automated backup retention in days (free-tier AWS accounts often cap this at 0-1)"
  type        = number
  default     = 0
}

# ──────────────────────────────────────────────
# Jump Server (EC2)
# ──────────────────────────────────────────────
variable "create_jump_server" {
  description = "Whether to create an EC2 jump server"
  type        = bool
  default     = true
}

variable "jump_server_instance_type" {
  description = "EC2 instance type for the jump server"
  type        = string
  default     = "t2.medium"
}

variable "jump_server_allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the jump server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
