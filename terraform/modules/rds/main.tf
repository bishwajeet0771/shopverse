# ──────────────────────────────────────────────
# DB Subnet Group (uses private subnets from the VPC module)
# ──────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-db-subnet-group"
  })
}

# ──────────────────────────────────────────────
# Security Group - only allow Postgres (5432) from EKS nodes
# ──────────────────────────────────────────────
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-rds-"
  description = "Allow Postgres access from EKS worker nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-rds-sg"
  })
}

# ──────────────────────────────────────────────
# RDS Postgres Instance (db.t3.micro)
# Master password is supplied manually via var.db_password
# (pass with -var, TF_VAR_db_password, or a GitHub Actions secret —
#  never commit it to terraform.tfvars)
# ──────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier     = "${var.name}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection
  apply_immediately       = true

  tags = merge(var.tags, {
    Name = "${var.name}-postgres"
  })
}

# ──────────────────────────────────────────────
# Secrets Manager - stores the connection details as JSON
# so the backend pod can fetch them at startup via IRSA.
# The password value here is the SAME one you set manually
# above via var.db_password - Terraform just mirrors it into
# Secrets Manager so nothing is duplicated by hand.
# ──────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name}/rds/postgres"
  description = "ShopVerse RDS Postgres connection credentials"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.this.address
    port     = tostring(aws_db_instance.this.port)
    dbname   = var.db_name
  })
}
