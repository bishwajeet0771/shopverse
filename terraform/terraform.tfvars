# ──────────────────────────────────────────────
# General
# ──────────────────────────────────────────────
aws_region   = "us-east-1"
project_name = "shopverse"

# ──────────────────────────────────────────────
# VPC
# ──────────────────────────────────────────────
vpc_cidr = "10.0.0.0/16"

# ──────────────────────────────────────────────
# EKS
# ──────────────────────────────────────────────
cluster_name       = "shopverse-cluster"
cluster_version    = "1.33"
node_instance_type = "c7i-flex.large"
node_desired_size  = 2
node_min_size      = 1
node_max_size      = 4

# ──────────────────────────────────────────────
# Jump Server (EC2)
# ──────────────────────────────────────────────
create_jump_server        = true
jump_server_instance_type = "c7i-flex.large"
#
