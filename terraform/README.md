# ShopVerse - Terraform Infrastructure

Provision the complete AWS infrastructure for ShopVerse from your local machine using Terraform modules.

## What Gets Created

| Resource | Module | Description |
|----------|--------|-------------|
| VPC | `modules/vpc` | VPC, 2 public subnets, 2 private subnets, IGW, NAT Gateway, route tables |
| EKS Cluster | `modules/eks` | EKS control plane, managed node group, OIDC provider, EBS CSI driver addon |
| IAM Roles | `modules/eks` | Cluster role, node role, ALB controller role, EBS CSI role |
| Jump Server | `modules/ec2` | Ubuntu 22.04 EC2 with kubectl, helm, docker pre-installed |

## Prerequisites

Install the following tools on your local machine:

```bash
# 1. Terraform (>= 1.5.0)
#    Download: https://developer.hashicorp.com/terraform/downloads

# 2. AWS CLI v2
#    Download: https://aws.amazon.com/cli/

# 3. kubectl
#    Download: https://kubernetes.io/docs/tasks/tools/

# 4. Helm 3
#    Download: https://helm.sh/docs/intro/install/
```

## Step 1: Configure AWS CLI

```bash
aws configure
# AWS Access Key ID: <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name: us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

## Step 2: Create S3 Backend (one-time setup)

Terraform needs an S3 bucket to store state remotely.

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket shopverse-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket shopverse-terraform-state \
  --versioning-configuration Status=Enabled
```

> If you don't want remote state, remove the `backend "s3"` block from `versions.tf` to use local state instead.

## Step 3: Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region   = "us-east-1"
project_name = "shopverse"

# VPC
vpc_cidr = "10.0.0.0/16"

# EKS
cluster_name       = "shopverse-cluster"
cluster_version    = "1.29"
node_instance_type = "t3.medium"
node_desired_size  = 2
node_min_size      = 1
node_max_size      = 4

# Jump Server
create_jump_server        = true
jump_server_instance_type = "t2.medium"

# RDS (Postgres) — db_password intentionally omitted, see below
db_name           = "shopverse"
db_username       = "shopverse"
db_instance_class = "db.t3.micro"
db_multi_az       = false
```

Set `create_jump_server = false` if you don't need a jump server.

`db_password` is **not** set in `terraform.tfvars` on purpose — it's a sensitive value and shouldn't be committed. Pass it as an environment variable instead:

```bash
export TF_VAR_db_password="ChangeMeToAStrongPassword123!"
```

## Step 4: Initialize Terraform

```bash
cd terraform

terraform init
```

If using S3 backend with different bucket/region:

```bash
terraform init \
  -backend-config="bucket=my-custom-bucket" \
  -backend-config="key=eks/terraform.tfstate" \
  -backend-config="region=us-east-1"
```

## Step 5: Plan and Review

```bash
terraform plan
```

Review the output carefully. It will show all resources to be created.

## Step 6: Apply

```bash
terraform apply
```

Type `yes` when prompted. This takes approximately 15-20 minutes (EKS cluster creation is the slowest part).

## Step 7: Connect to the EKS Cluster

After `terraform apply` completes, it outputs the kubeconfig command:

```bash
# Copy the kubeconfig command from terraform output
aws eks update-kubeconfig --name shopverse-cluster --region us-east-1

# Verify connection
kubectl get nodes
kubectl cluster-info
```

## Step 8: Connect to the Jump Server

Go to AWS Console > EC2 > Instances > Select the jump server > Click **Connect** > Use **EC2 Instance Connect**.

The jump server comes pre-installed with:
- AWS CLI v2
- kubectl (with kubeconfig already configured)
- Helm 3
- Docker
- Git

Once connected:

```bash
# Verify kubectl is working
kubectl get nodes

# Verify helm
helm version

# Check cluster pods
kubectl get pods -A
```

## Terraform Outputs

After apply, view all outputs:

```bash
terraform output
```

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | EKS API server endpoint |
| `alb_controller_role_arn` | IAM role ARN for ALB controller |
| `ebs_csi_role_arn` | IAM role ARN for EBS CSI driver |
| `jump_server_public_ip` | Jump server public IP |
| `jump_server_instance_id` | Jump server EC2 instance ID |
| `jump_server_console_url` | Direct link to connect via AWS Console |
| `kubeconfig_command` | Command to configure kubectl |

## Deploy ShopVerse Application

After the infrastructure is ready:

```bash
# 1. Create ECR repositories
aws ecr create-repository --repository-name shopverse-frontend --region us-east-1
aws ecr create-repository --repository-name shopverse-backend --region us-east-1

# 2. Login to ECR
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# 3. Build and push images (from project root)
cd ..
docker build -t ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/shopverse-frontend:v1 ./frontend
docker build -t ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/shopverse-backend:v1 ./backend
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/shopverse-frontend:v1
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/shopverse-backend:v1

# 4. Install ALB controller
ALB_ROLE_ARN=$(cd terraform && terraform output -raw alb_controller_role_arn)
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=shopverse-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN

# 5. Deploy with Helm
RDS_HOST=$(terraform output -raw db_address)
RDS_PORT=$(terraform output -raw db_port)

helm upgrade --install shopverse ./helm/shopverse \
  --set frontend.image=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/shopverse-frontend:v1 \
  --set backend.image=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/shopverse-backend:v1 \
  --set postgres.host=${RDS_HOST} \
  --set postgres.port=${RDS_PORT} \
  --set-string postgres.password=YourAppPassword123 \
  --set jwtSecret=YourJwtSecretKey123 \
  --namespace shopverse \
  --create-namespace \
  --wait --timeout 600s

# 6. Verify
kubectl get pods -n shopverse
kubectl get svc -n shopverse
```

## Modify Infrastructure

To change any resource (e.g., scale nodes, change instance type):

```bash
# Edit terraform.tfvars
# Example: change node_desired_size = 3

terraform plan    # Review changes
terraform apply   # Apply changes
```

## Destroy Infrastructure

To tear down everything:

```bash
# First, delete Kubernetes resources (Helm release, etc.)
helm uninstall shopverse -n shopverse
kubectl delete namespace shopverse

# Then destroy Terraform-managed infrastructure
terraform destroy
```

Type `yes` when prompted. This removes all AWS resources created by Terraform.

> **Warning:** `terraform destroy` will delete the EKS cluster, VPC, RDS instance, jump server, and all associated resources. Make sure you have backed up any important data.
>
> The RDS module defaults `deletion_protection = true`, so `terraform destroy` will fail on the DB instance until you either set `deletion_protection = false` (in `terraform.tfvars` or via `-var`) or disable it manually first. This is intentional — it's a guardrail against accidentally destroying production data.

## Module Structure

```
terraform/
├── main.tf                       # Root - wires all modules together
├── variables.tf                  # Root input variables
├── outputs.tf                    # Root outputs from all modules
├── versions.tf                   # Provider versions + S3 backend
├── terraform.tfvars.example      # Example variable values
└── modules/
    ├── vpc/
    │   ├── main.tf               # VPC, subnets, IGW, NAT, route tables
    │   ├── variables.tf          # name, vpc_cidr, cluster_name
    │   └── outputs.tf            # vpc_id, public/private subnet IDs
    ├── eks/
    │   ├── main.tf               # Cluster, node group, OIDC, ALB role, EBS CSI
    │   ├── variables.tf          # cluster config, node config
    │   └── outputs.tf            # endpoints, role ARNs, OIDC
    ├── rds/
    │   ├── main.tf               # Postgres instance (db.t3.micro), subnet group, SG
    │   ├── variables.tf          # db_name, db_username, db_password, instance_class
    │   └── outputs.tf            # db_address, db_port, db_endpoint
    └── ec2/
        ├── main.tf               # Ubuntu EC2, IAM role, security group
        ├── userdata.sh           # Bootstraps kubectl, helm, docker
        ├── variables.tf          # instance_type, cluster_name
        └── outputs.tf            # public_ip, instance_id, console URL
```

## Troubleshooting

### Terraform init fails with S3 backend error
```bash
# Make sure the S3 bucket exists (see Step 2)
# Or remove the backend block from versions.tf to use local state
```

### EKS cluster creation times out
```bash
# EKS takes ~15 minutes. If it times out, just run again:
terraform apply
```

### Jump server userdata didn't run
```bash
# Check cloud-init logs after connecting
sudo cat /var/log/cloud-init-output.log
```

### kubectl can't connect from jump server
```bash
# Re-run kubeconfig setup
aws eks update-kubeconfig --name shopverse-cluster --region us-east-1

# Verify IAM role has permissions
aws sts get-caller-identity
```

### Nodes not joining the cluster
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name shopverse-cluster \
  --nodegroup-name shopverse-cluster-nodes \
  --region us-east-1 \
  --query 'nodegroup.status'
```
