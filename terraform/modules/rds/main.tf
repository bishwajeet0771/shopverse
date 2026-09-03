# ──────────────────────────────────────────────
# DB Subnet Group (spans the private subnets / 2 AZs)
# ──────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

# ──────────────────────────────────────────────
# Security Group — only allow Postgres (5432) from
# the EKS node/cluster security group, nothing else
# ──────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  description = "Allow Postgres access from EKS nodes only"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-sg"
  })
}

resource "aws_security_group_rule" "rds_ingress" {
  count = length(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
  description              = "Postgres from EKS nodes"
}

# ──────────────────────────────────────────────
# Parameter Group (placeholder for future tuning)
# ──────────────────────────────────────────────
resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.project_name}-pg16-"
  family      = "postgres16"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ──────────────────────────────────────────────
# RDS Postgres Instance (db.t3.micro)
# ──────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier     = "${var.project_name}-postgres"
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
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az            = var.multi_az
  publicly_accessible = false

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:30-mon:05:30"

  deletion_protection      = var.deletion_protection
  skip_final_snapshot      = var.skip_final_snapshot
  final_snapshot_identifier = "${var.project_name}-postgres-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-postgres"
  })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}
