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
# RDS Module (Postgres, db.t3.micro)
# ──────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  name                = var.project_name
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  eks_node_sg_id      = module.eks.node_security_group_id
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  tags                = local.common_tags
}

# ──────────────────────────────────────────────
# IRSA Role for the backend pod - allows it to read
# only the RDS connection secret from Secrets Manager
# ──────────────────────────────────────────────
resource "aws_iam_role" "backend_irsa" {
  name = "${var.cluster_name}-backend-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(module.eks.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:shopverse:shopverse-backend"
          "${replace(module.eks.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "backend_secrets_access" {
  name = "${var.cluster_name}-backend-secrets-access"
  role = aws_iam_role.backend_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = module.rds.db_secret_arn
    }]
  })
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
