locals {
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "terraform"
    Environment = "production"
  }
}

# ──────────────────────────────────────────────
# VPC Module
# ──────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  name         = var.project_name
  vpc_cidr     = var.vpc_cidr
  cluster_name = var.cluster_name
  tags         = local.common_tags
}

# ──────────────────────────────────────────────
# EKS Module
# ──────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  tags               = local.common_tags
}

# ──────────────────────────────────────────────
# RDS Module (Postgres — replaces in-cluster MySQL StatefulSet)
# ──────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids

  # Only the EKS node/cluster security group may reach Postgres
  allowed_security_group_ids = [module.eks.node_security_group_id]

  db_name        = var.db_name
  db_username    = var.db_username
  db_password    = var.db_password
  instance_class = var.db_instance_class
  multi_az       = var.db_multi_az
  deletion_protection = var.db_deletion_protection

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# EC2 Jump Server Module (conditional)
# ──────────────────────────────────────────────
module "jump_server" {
  source = "./modules/ec2"
  count  = var.create_jump_server ? 1 : 0

  name              = "${var.project_name}-jump-server"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  instance_type     = var.jump_server_instance_type
  allowed_ssh_cidrs = var.jump_server_allowed_ssh_cidrs
  cluster_name      = var.cluster_name
  aws_region        = var.aws_region
  tags              = local.common_tags
}
