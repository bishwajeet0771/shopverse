# ──────────────────────────────────────────────
# VPC Outputs
# ──────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# ──────────────────────────────────────────────
# EKS Outputs
# ──────────────────────────────────────────────
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority" {
  description = "EKS cluster CA certificate"
  value       = module.eks.cluster_certificate_authority
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_group_role_arn" {
  description = "IAM role ARN for the node group"
  value       = module.eks.node_group_role_arn
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for the ALB controller"
  value       = module.eks.alb_controller_role_arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI driver"
  value       = module.eks.ebs_csi_role_arn
}

# ──────────────────────────────────────────────
# RDS Outputs
# ──────────────────────────────────────────────
output "db_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = module.rds.db_endpoint
}

output "db_address" {
  description = "RDS hostname only — feed this into Helm as postgres.host"
  value       = module.rds.db_address
}

output "db_port" {
  description = "RDS port"
  value       = module.rds.db_port
}

# ──────────────────────────────────────────────
# Jump Server Outputs
# ──────────────────────────────────────────────
output "jump_server_public_ip" {
  description = "Public IP of the jump server"
  value       = var.create_jump_server ? module.jump_server[0].public_ip : null
}

output "jump_server_console_url" {
  description = "AWS Console URL to connect to the jump server"
  value       = var.create_jump_server ? module.jump_server[0].console_connect_url : null
}

output "jump_server_instance_id" {
  description = "Instance ID of the jump server"
  value       = var.create_jump_server ? module.jump_server[0].instance_id : null
}

# ──────────────────────────────────────────────
# Kubeconfig Command
# ──────────────────────────────────────────────
output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
