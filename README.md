# ShopVerse - Full-Stack E-Commerce Application

A production-ready 3-tier e-commerce web application built with React, Go (Fiber), and **AWS RDS Postgres**, deployed on AWS EKS using Helm charts.



<img width="1280" height="720" alt="Shopverse project - Thumbnail" src="https://github.com/user-attachments/assets/fd0a3efe-aeb3-48dc-8912-714517580010" />


## YouTube Video Link:

```
https://youtu.be/XQrJrf6pUvk?si=XGsLPOm6YC1AEJFk
```

> **Note:** The video/thumbnail above reflects the original MySQL-based architecture. The database layer has since been migrated to AWS RDS (Postgres) — see the architecture and steps below for the current setup.

## Architecture:

```
                         +------------------+
                         |   AWS ALB        |
                         | (Ingress Controller) |
                         +--------+---------+
                                  |
                    +-------------+-------------+
                    |                           |
              /api/* routes               /* routes
                    |                           |
           +--------v---------+     +-----------v----------+
           | Backend Service  |     | Frontend Service     |
           | (Go + Fiber)     |     | (React + Nginx)      |
           | Port 8080        |     | Port 80              |
           | NodePort: 30081  |     | NodePort: 30080      |
           | 2 replicas       |     | 2 replicas           |
           +--------+---------+     +----------------------+
                    |
                    | (private subnet, port 5432, SG-restricted)
                    |
           +--------v---------------+
           | AWS RDS Postgres        |
           | db.t3.micro             |
           | Multi-AZ: optional      |
           | 20Gi gp3, encrypted     |
           +--------------------------+
```

The database now runs **outside the EKS cluster** as a managed AWS RDS instance, in the same VPC's private subnets. The backend reaches it over the internal network; nothing outside the EKS node security group can connect to it.

## Tech Stack

| Layer    | Technology                     |
|----------|--------------------------------|
| Frontend | React 18, TailwindCSS, Vite    |
| Backend  | Go 1.21, Fiber, GORM, JWT      |
| Database | AWS RDS Postgres 16 (db.t3.micro) |
| Infra    | AWS EKS, ECR, ALB, RDS, Terraform |
| CI/CD    | GitHub Actions, Helm, Trivy    |
| IaC      | Terraform Modules (VPC, EKS, RDS, EC2) |

## API Endpoints

| Method | Endpoint            | Auth     | Description             |
|--------|---------------------|----------|-------------------------|
| POST   | /api/auth/register  | No       | Register new user       |
| POST   | /api/auth/login     | No       | Login, returns JWT      |
| GET    | /api/products       | No       | List products           |
| GET    | /api/products/:id   | No       | Get single product      |
| POST   | /api/products       | JWT      | Create product (admin)  |
| GET    | /api/cart           | JWT      | Get user's cart         |
| POST   | /api/cart           | JWT      | Add item to cart        |
| PUT    | /api/cart/:id       | JWT      | Update cart item qty    |
| DELETE | /api/cart/:id       | JWT      | Remove cart item        |
| GET    | /api/orders         | JWT      | Get user's orders       |
| POST   | /api/orders         | JWT      | Place order from cart   |
| GET    | /health             | No       | Health check            |

---

## Local Development

### Prerequisites
- Docker & Docker Compose
- Node.js 18+ (for frontend dev)
- Go 1.21+ (for backend dev)

### Quick Start with Docker Compose

```bash
# Clone the repo
git clone <repo-url> && cd shopverse

# Start all services
docker-compose up --build

# Access the app
# Frontend: http://localhost:3000
# Backend:  http://localhost:8080
```

### Run Frontend Individually (Hot Reload)

```bash
cd frontend
npm install
npm run dev
# Runs on http://localhost:3000 with proxy to backend
```

### Run Backend Individually

```bash
cd backend
go mod tidy
DB_HOST=localhost DB_PORT=5432 DB_USER=shopverse DB_PASSWORD=shopverse123 DB_NAME=shopverse DB_SSLMODE=disable go run ./cmd/main.go
```

---

## AWS Deployment (Step-by-Step from Local)

### Prerequisites

Install the following tools on your local machine:

| Tool       | Version  | Download |
|------------|----------|----------|
| Terraform  | >= 1.5.0 | https://developer.hashicorp.com/terraform/downloads |
| AWS CLI v2 | Latest   | https://aws.amazon.com/cli/ |
| kubectl    | Latest   | https://kubernetes.io/docs/tasks/tools/ |
| Helm 3     | Latest   | https://helm.sh/docs/intro/install/ |
| Docker     | Latest   | https://docs.docker.com/get-docker/ |

---

### Step 1: Configure AWS CLI

```bash
aws configure
# AWS Access Key ID: <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name: us-east-1
# Default output format: json

# Verify your identity
aws sts get-caller-identity
```

---

### Step 2: Create AWS Infrastructure using Terraform

Terraform modules will create: VPC, EKS Cluster, Node Group, IAM Roles, RDS Postgres instance (`db.t3.micro`), Jump Server (EC2).

See [terraform/README.md](terraform/README.md) for detailed Terraform instructions.

```bash
cd terraform

# Create S3 bucket for Terraform state (one-time setup)
aws s3api create-bucket \
  --bucket shopverse-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket shopverse-terraform-state \
  --versioning-configuration Status=Enabled

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (cluster name, region, instance types, db_name, db_username, etc.)

# The RDS master password is NOT set in terraform.tfvars — pass it via an
# environment variable so it never gets committed to git:
export TF_VAR_db_password="ChangeMeToAStrongPassword123!"

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Create the infrastructure (~15-20 minutes)
terraform apply
# Type 'yes' when prompted
```

After apply completes, note the outputs:
```bash
terraform output
# db_address / db_port give you the RDS endpoint the app will connect to
```

---

### Step 3: Connect to the EKS Cluster

```bash
# Update your local kubeconfig (use cluster name from terraform output)
aws eks update-kubeconfig --name shopverse-cluster --region us-east-1

# Verify connection - you should see your worker nodes
kubectl get nodes
kubectl cluster-info
```

---

### Step 4: Create ECR Repositories

Create 3 ECR repositories for frontend, backend, and Helm chart:

```bash
# Get your AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1

# Create repositories
aws ecr create-repository --repository-name shopverse-frontend --region $REGION
aws ecr create-repository --repository-name shopverse-backend --region $REGION
aws ecr create-repository --repository-name shopverse-helmchart --region $REGION

# Verify repositories were created
aws ecr describe-repositories --region $REGION --query 'repositories[].repositoryName'
```

---

### Step 5: Build Docker Images

```bash
# Navigate to project root
cd ..

# Build frontend image
docker build -t shopverse-frontend:v1 ./frontend

# Build backend image
docker build -t shopverse-backend:v1 ./backend

# Verify images were built
docker images | grep shopverse
```

---

### Step 6: Tag Docker Images

Tag the images with the ECR repository URI:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ECR_URI=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Tag frontend image
docker tag shopverse-frontend:v1 ${ECR_URI}/shopverse-frontend:v1

# Tag backend image
docker tag shopverse-backend:v1 ${ECR_URI}/shopverse-backend:v1

# Verify tags
docker images | grep ${ACCOUNT_ID}
```

---

### Step 7: Push Docker Images to ECR

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ECR_URI=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Login to ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin ${ECR_URI}

# Push frontend image
docker push ${ECR_URI}/shopverse-frontend:v1

# Push backend image
docker push ${ECR_URI}/shopverse-backend:v1

# Verify images in ECR
aws ecr list-images --repository-name shopverse-frontend --region $REGION
aws ecr list-images --repository-name shopverse-backend --region $REGION
```

---

### Step 8: Push Helm Chart to ECR (Optional)

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ECR_URI=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Login to ECR for Helm
aws ecr get-login-password --region $REGION | \
  helm registry login --username AWS --password-stdin ${ECR_URI}

# Package the Helm chart
helm package ./helm/shopverse

# Push Helm chart to ECR
helm push shopverse-1.0.0.tgz oci://${ECR_URI}/shopverse-helmchart

# Verify
aws ecr list-images --repository-name shopverse-helmchart --region $REGION
```

---

### Step 9: Install EKS Add-ons

```bash
# EBS CSI Driver: only needed if you add other PersistentVolumeClaims later.
# The database no longer runs in-cluster (it's RDS), so it's optional now,
# but the Terraform EKS module still installs it by default as a convenience.
# If using Terraform modules, EBS CSI is already installed as an addon.
# If not, install manually:
eksctl utils associate-iam-oidc-provider --cluster shopverse-cluster --region us-east-1 --approve

eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster shopverse-cluster \
  --region us-east-1 \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

aws eks create-addon --cluster-name shopverse-cluster --addon-name aws-ebs-csi-driver --region us-east-1

# Install AWS Load Balancer Controller (required for ALB Ingress)
ALB_ROLE_ARN=$(cd terraform && terraform output -raw alb_controller_role_arn)

helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=shopverse-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN
```

---

### Step 10: Deploy Application using Helm

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
ECR_URI=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Get the RDS endpoint from Terraform output
RDS_HOST=$(cd terraform && terraform output -raw db_address)
RDS_PORT=$(cd terraform && terraform output -raw db_port)

helm upgrade --install shopverse ./helm/shopverse \
  --set frontend.image=${ECR_URI}/shopverse-frontend:v1 \
  --set backend.image=${ECR_URI}/shopverse-backend:v1 \
  --set postgres.host=${RDS_HOST} \
  --set postgres.port=${RDS_PORT} \
  --set-string postgres.password=YourAppPassword123 \
  --set jwtSecret=YourJwtSecretKey123 \
  --namespace shopverse \
  --create-namespace \
  --wait --timeout 600s
```

> `postgres.password` must match the `db_password` used when running `terraform apply` for the RDS master password (or the app-level password, if you later split master vs. app credentials).

---

### Step 11: Verify Deployment

```bash
# Check all pods are running (should see 4 pods: 2 frontend, 2 backend — no DB pod, it's RDS)
kubectl get pods -n shopverse

# Check services (frontend NodePort:30080, backend NodePort:30081)
kubectl get svc -n shopverse

# Check all resources at once
kubectl get all -n shopverse

# Check pod logs if needed
kubectl logs -n shopverse -l component=backend --tail=50
kubectl logs -n shopverse -l component=frontend --tail=50

# Check RDS instance status directly
aws rds describe-db-instances \
  --db-instance-identifier shopverse-postgres \
  --region us-east-1 \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address,Endpoint.Port]' \
  --output table
```

---

### Step 12: Access the Application

**Get Node External IPs:**
```bash
kubectl get nodes -o wide
# Note the EXTERNAL-IP column
```

**Access via NodePort:**
```
Frontend:  http://<NODE_EXTERNAL_IP>:30080
Backend:   http://<NODE_EXTERNAL_IP>:30081
Health:    http://<NODE_EXTERNAL_IP>:30081/health
```

**Access via ALB Ingress (if configured):**
```bash
kubectl get ingress -n shopverse
# Use the ADDRESS field as the URL
```

> **Note:** Make sure the EKS node security group allows inbound traffic on ports **30080** and **30081**. You can update this in AWS Console > EC2 > Security Groups > find the node security group > add inbound rules for Custom TCP ports 30080 and 30081 from `0.0.0.0/0`.

---

## Connect to Jump Server

If you created a jump server via Terraform (`create_jump_server = true`):

1. Go to **AWS Console** > **EC2** > **Instances**
2. Select the jump server instance
3. Click **Connect** > Choose **EC2 Instance Connect** > Click **Connect**

The jump server comes pre-installed with: AWS CLI, kubectl, Helm, Docker, Git.

```bash
# Once connected, verify tools
kubectl get nodes
helm version
docker --version

# Check application pods
kubectl get pods -n shopverse
kubectl get svc -n shopverse
```

---

## Querying the Database

### Understanding the Database

ShopVerse uses **AWS RDS Postgres** (`db.t3.micro`). It's not reachable from your laptop directly (it lives in a private subnet) — query it either from the jump server EC2 instance, or via `kubectl exec` into a running backend pod (since the backend pod's network path to RDS is already open).

| Table | Description |
|-------|-------------|
| `users` | Registered users (name, email, hashed password) |
| `products` | Product catalog - 28 products across 6 categories |
| `orders` | Customer orders (total amount, status, timestamps) |
| `order_items` | Individual items within each order (product, quantity, price) |
| `cart_items` | Current shopping cart contents per user |

### Step 1: Get the Database Password

The Postgres password is stored as a Kubernetes secret (base64 encoded):

```bash
DB_PASSWORD=$(kubectl get secret -n shopverse shopverse-secret \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)

echo $DB_PASSWORD
```

### Step 2: Get the RDS Endpoint

```bash
DB_HOST=$(cd terraform && terraform output -raw db_address)
echo $DB_HOST
```

### Step 3: Connect via `psql`

**Option A — from the jump server** (has network access into the VPC's private subnets):

1. Connect to the jump server via **EC2 Instance Connect** (see "Connect to Jump Server" below).
2. Install the Postgres client if it's not already there: `sudo dnf install -y postgresql16` (Amazon Linux) or `sudo apt-get install -y postgresql-client` (Ubuntu).
3. Connect:
```bash
psql "host=<DB_HOST> port=5432 dbname=shopverse user=shopverse password=<DB_PASSWORD> sslmode=require"
```

**Option B — from inside a running backend pod** (no extra tooling to install, since the pod already has network access):
```bash
kubectl exec -it -n shopverse deployment/shopverse-backend -- sh
# then, if psql isn't in the image, fall back to querying through the Go app's /health
# or add a one-off debug pod with the postgres image instead:
kubectl run -it --rm psql-debug -n shopverse --image=postgres:16 --restart=Never -- \
  psql "host=$DB_HOST port=5432 dbname=shopverse user=shopverse password=$DB_PASSWORD sslmode=require"
```

### Step 4: Run Queries

Once connected (you'll see a `shopverse=>` prompt):

#### View all tables
```sql
\dt
```

#### View registered users
```sql
SELECT id, name, email, created_at FROM users;
```

#### View all products
```sql
SELECT id, name, category, price, original_price, rating, badge FROM products;
```

#### View products grouped by category
```sql
SELECT category, COUNT(*) AS total_products,
       ROUND(AVG(price)::numeric, 2) AS avg_price,
       ROUND(MIN(price)::numeric, 2) AS min_price,
       ROUND(MAX(price)::numeric, 2) AS max_price
FROM products
GROUP BY category
ORDER BY total_products DESC;
```

#### View all orders with customer info
```sql
SELECT
    o.id AS order_id,
    u.name AS customer_name,
    u.email AS customer_email,
    o.total_amount,
    o.status,
    o.created_at AS order_date
FROM orders o
JOIN users u ON o.user_id = u.id
ORDER BY o.created_at DESC;
```

#### View order items with product details
```sql
SELECT
    oi.order_id,
    p.name AS product_name,
    p.category,
    oi.quantity,
    oi.price AS unit_price,
    (oi.quantity * oi.price) AS subtotal
FROM order_items oi
JOIN products p ON oi.product_id = p.id
ORDER BY oi.order_id, p.name;
```

#### View complete order breakdown (orders + items together)
```sql
SELECT
    o.id AS order_id,
    u.name AS customer,
    p.name AS product,
    oi.quantity,
    oi.price AS unit_price,
    (oi.quantity * oi.price) AS subtotal,
    o.total_amount AS order_total,
    o.status,
    o.created_at
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
ORDER BY o.id, p.name;
```

#### View current cart items
```sql
SELECT
    ci.id AS cart_item_id,
    u.name AS customer,
    p.name AS product,
    p.category,
    ci.quantity,
    p.price AS unit_price,
    (ci.quantity * p.price) AS subtotal
FROM cart_items ci
JOIN users u ON ci.user_id = u.id
JOIN products p ON ci.product_id = p.id
ORDER BY u.name;
```

#### Dashboard summary
```sql
SELECT
    (SELECT COUNT(*) FROM users) AS total_users,
    (SELECT COUNT(*) FROM products) AS total_products,
    (SELECT COUNT(*) FROM orders) AS total_orders,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders) AS total_revenue,
    (SELECT COUNT(*) FROM cart_items) AS items_in_carts;
```

#### Exit `psql`
```sql
\q
```

### Quick One-Liner Queries (Without an Interactive Session)

```bash
DB_HOST=$(cd terraform && terraform output -raw db_address)
DB_PASSWORD=$(kubectl get secret -n shopverse shopverse-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)

# List all registered users
kubectl run -it --rm psql-debug -n shopverse --image=postgres:16 --restart=Never -- \
  psql "host=$DB_HOST port=5432 dbname=shopverse user=shopverse password=$DB_PASSWORD sslmode=require" \
  -c "SELECT id, name, email, created_at FROM users;"

# Quick dashboard summary
kubectl run -it --rm psql-debug -n shopverse --image=postgres:16 --restart=Never -- \
  psql "host=$DB_HOST port=5432 dbname=shopverse user=shopverse password=$DB_PASSWORD sslmode=require" \
  -c "SELECT (SELECT COUNT(*) FROM users) AS users, (SELECT COUNT(*) FROM products) AS products, (SELECT COUNT(*) FROM orders) AS orders, (SELECT COALESCE(SUM(total_amount),0) FROM orders) AS revenue;"
```

**How the `-c` flag works:**
- `-c "SQL QUERY"` executes the query and exits immediately (no interactive shell) — same idea as MySQL's `-e` flag.

---

## CI/CD Pipeline (GitHub Actions)

### Configure GitHub Secrets

Go to your GitHub repo > Settings > Secrets and variables > Actions, and add:

| Secret                  | Description                                          |
|-------------------------|------------------------------------------------------|
| `AWS_ACCESS_KEY_ID`     | IAM user access key                                  |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key                                  |
| `AWS_REGION`            | e.g., `us-east-1`                                    |
| `ECR_REGISTRY`          | e.g., `123456789.dkr.ecr.us-east-1.amazonaws.com`    |
| `EKS_CLUSTER_NAME`      | e.g., `shopverse-cluster`                            |
| `TF_STATE_BUCKET`       | Name of the S3 bucket holding Terraform state        |
| `DB_PASSWORD`           | RDS master/app Postgres password (used by both Terraform and Helm) |
| `JWT_SECRET`            | shopverse-secret-key-2024                            |

### Pipeline Stages

Push to `main` branch triggers the 4-stage pipeline:

1. **Test** - Go tests + frontend linting
2. **Security Scan** - Trivy vulnerability scanning on Docker images
3. **Build & Push** - Build images, tag with SHA, push to ECR
4. **Deploy** - Provision infra with Terraform if needed, deploy Helm chart

---

## Modify / Scale the Application

```bash
# Scale frontend to 3 replicas
kubectl scale deployment shopverse-frontend -n shopverse --replicas=3

# Scale backend to 3 replicas
kubectl scale deployment shopverse-backend -n shopverse --replicas=3

# Rolling restart (picks up new config without downtime)
kubectl rollout restart deployment/shopverse-frontend -n shopverse
kubectl rollout restart deployment/shopverse-backend -n shopverse

# Update images (deploy new version)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

helm upgrade shopverse ./helm/shopverse \
  --set frontend.image=${ECR_URI}/shopverse-frontend:v2 \
  --set backend.image=${ECR_URI}/shopverse-backend:v2 \
  --reuse-values -n shopverse
```

## Destroy Everything

```bash
# Step 1: Delete application resources
helm uninstall shopverse -n shopverse
kubectl delete pvc --all -n shopverse
kubectl delete namespace shopverse

# Step 2: Destroy AWS infrastructure
cd terraform
terraform destroy
# Type 'yes' when prompted
```

> **Warning:** This deletes the EKS cluster, VPC, jump server, and all associated resources.

---

## Project Structure

```
shopverse/
├── frontend/                  # React + TailwindCSS (Vite)
│   ├── src/
│   │   ├── components/        # Navbar, ProductCard, CartSidebar
│   │   ├── pages/             # Auth, Home, Products, Cart, Orders, Wishlist
│   │   ├── App.jsx            # Routes, context, API client
│   │   └── main.jsx           # Entry point
│   ├── Dockerfile             # Multi-stage: Node -> Nginx
│   └── nginx.conf             # React Router + API proxy
├── backend/                   # Go + Fiber REST API
│   ├── cmd/main.go            # Entry point, routes
│   ├── internal/
│   │   ├── handlers/          # Auth, Products, Cart, Orders
│   │   ├── models/            # GORM models
│   │   ├── database/          # DB connection + seed data (28 products)
│   │   └── middleware/        # JWT auth middleware
│   └── Dockerfile             # Multi-stage: Go -> Distroless
├── helm/shopverse/            # Helm chart
│   ├── templates/             # K8s manifests
│   │   ├── secret.yaml        # DB password, JWT secret
│   │   ├── configmap.yaml     # DB host, port, name, sslmode config (points at RDS)
│   │   ├── backend-deployment.yaml # Go API (2 replicas)
│   │   ├── backend-service.yaml    # NodePort 30081
│   │   ├── frontend-deployment.yaml # React+Nginx (2 replicas)
│   │   ├── frontend-service.yaml    # NodePort 30080
│   │   └── ingress.yaml            # ALB ingress
│   ├── values.yaml            # Configurable values (postgres.* points at RDS)
│   └── Chart.yaml             # Chart metadata
├── terraform/                 # Infrastructure as Code (Modules)
│   ├── main.tf                # Root - wires all modules
│   ├── variables.tf           # Root input variables
│   ├── outputs.tf             # Root outputs (incl. db_address/db_port)
│   ├── versions.tf            # Provider versions + S3 backend
│   ├── terraform.tfvars.example
│   ├── README.md              # Detailed Terraform guide
│   └── modules/
│       ├── vpc/               # VPC, subnets, IGW, NAT, routes
│       ├── eks/               # EKS cluster, node group, OIDC, addons
│       ├── rds/                # RDS Postgres instance (db.t3.micro), subnet group, SG
│       └── ec2/               # Jump server (Ubuntu 22.04)
├── .github/workflows/         # CI/CD pipeline
│   └── deploy.yml             # 4-stage: test -> scan -> build -> deploy
├── docker-compose.yml         # Local development
└── README.md
```

## Troubleshooting

### Pods stuck in Pending
```bash
kubectl describe pod <pod-name> -n shopverse
# The database no longer runs in-cluster (RDS), so this is now almost always
# a scheduling/resource issue on the frontend or backend deployments, not a
# PVC-binding issue.
```

### Frontend can't reach backend (502/504)
```bash
kubectl get svc -n shopverse
kubectl logs -n shopverse -l component=backend
# Verify backend pods are running and healthy
```

### Backend can't connect to the database
```bash
kubectl logs -n shopverse -l component=backend
# Common causes:
# 1. RDS security group doesn't allow the EKS node SG on port 5432
#    -> check terraform/modules/rds/main.tf's aws_security_group_rule
# 2. Wrong DB_HOST/DB_PORT in the ConfigMap
#    -> kubectl get configmap shopverse-config -n shopverse -o yaml
# 3. RDS instance still provisioning (can take 5-10 min on first apply)
aws rds describe-db-instances --db-instance-identifier shopverse-postgres --region us-east-1 \
  --query 'DBInstances[0].DBInstanceStatus'
```

### Can't access NodePort from browser
```bash
# Check node security group allows ports 30080 and 30081
# AWS Console > EC2 > Security Groups > Node security group > Inbound rules
# Add: Custom TCP, Port 30080, Source 0.0.0.0/0
# Add: Custom TCP, Port 30081, Source 0.0.0.0/0
```

### Images not updating after push
```bash
# Use a new tag instead of reusing the same one
helm upgrade shopverse ./helm/shopverse \
  --set frontend.image=<ECR>/shopverse-frontend:v2 \
  --set backend.image=<ECR>/shopverse-backend:v2 \
  --reuse-values -n shopverse
```

## CI/CD Pipeline File

The full, current CI/CD pipeline lives at [`.github/workflows/deploy.yaml`](.github/workflows/deploy.yaml) — that file is the single source of truth (this README no longer duplicates it inline, to avoid the two drifting out of sync). Key points about the current version:

- Terraform now runs on **every** deploy (not just on first EKS cluster creation), since the RDS endpoint needs to be read via `terraform output` on each run — `terraform apply` is idempotent, so this is a no-op once infrastructure exists.
- The `postgres.host` / `postgres.port` Helm values are populated from Terraform's `db_address` / `db_port` outputs at deploy time, rather than hardcoded.
- `MYSQL_ROOT_PASSWORD` / `MYSQL_PASSWORD` GitHub secrets are replaced by a single `DB_PASSWORD` secret (used both as the RDS master password via `TF_VAR_db_password`, and as the app's DB password in the Helm release).

---

## License

MIT
