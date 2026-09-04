  variable "name" {
    description = "Name for the jump server and its resources"
    type        = string
  }

  variable "vpc_id" {
    description = "VPC ID where the jump server will be launched"
    type        = string
  }

  variable "subnet_id" {
    description = "Public subnet ID for the jump server"
    type        = string
  }

  variable "instance_type" {
    description = "EC2 instance type"
    type        = string
    default     = "t2.medium"
  }

  variable "volume_size" {
    description = "Root volume size in GB"
    type        = number
    default     = 20
  }

  variable "allowed_ssh_cidrs" {
    description = "CIDR blocks allowed to SSH into the jump server"
    type        = list(string)
    default     = ["0.0.0.0/0"]
  }

  variable "cluster_name" {
    description = "EKS cluster name (for kubeconfig setup in userdata)"
    type        = string
  }

  variable "aws_region" {
    description = "AWS region"
    type        = string
  }

  variable "tags" {
    description = "Common tags for all resources"
    type        = map(string)
    default     = {}
  }
