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
# RDS PostgreSQL Module
# ──────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  name = "${var.project_name}-postgres"

  vpc_id = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_subnet_ids

  # PostgreSQL access from EKS.
  #
  # IMPORTANT:
  # Verify that this is the security group used by the
  # backend workload/network path. If the backend traffic
  # originates from the EKS node security group, use that
  # security group instead.
  allowed_security_group_ids = [
    module.eks.custom_cluster_security_group_id
  ]

  database_name = "shopverse"
  username      = "shopverse"

  engine_version = "16"

  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 20

  backup_retention_period = 0

  multi_az = false

  deletion_protection = true

  skip_final_snapshot = false

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# IAM Role for ShopVerse Backend
# ──────────────────────────────────────────────
resource "aws_iam_role" "shopverse_backend" {
  name = "${var.cluster_name}-shopverse-backend"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
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
      }
    ]
  })

  tags = local.common_tags
}

# ──────────────────────────────────────────────
# Allow Backend to Read RDS Credentials
# ──────────────────────────────────────────────
resource "aws_iam_role_policy" "shopverse_backend_secrets" {
  name = "${var.cluster_name}-shopverse-backend-secrets"

  role = aws_iam_role.shopverse_backend.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = module.rds.master_user_secret_arn
      }
    ]
  })
}

# ──────────────────────────────────────────────
# EC2 Jump Server Module (conditional)
# ──────────────────────────────────────────────
module "jump_server" {
  source = "./modules/ec2"

  count = var.create_jump_server ? 1 : 0

  name              = "${var.project_name}-jump-server"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  instance_type     = var.jump_server_instance_type
  allowed_ssh_cidrs = var.jump_server_allowed_ssh_cidrs
  cluster_name      = var.cluster_name
  aws_region        = var.aws_region
  tags              = local.common_tags
}
