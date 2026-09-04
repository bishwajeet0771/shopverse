# MySQL → AWS RDS Postgres (db.t3.micro) Migration

This zip contains the full repo with the migration already applied. Here's what changed and what you need to do manually.

## What changed

| File | Change |
|---|---|
| `terraform/modules/rds/*` | **New.** Creates the `db.t3.micro` Postgres RDS instance, a DB subnet group (private subnets), a security group (5432 from EKS nodes only), and a Secrets Manager secret mirroring the connection details. |
| `terraform/main.tf` | Added `module "rds"` call + IRSA IAM role (`aws_iam_role.backend_irsa`) so the backend pod can read the DB secret. |
| `terraform/variables.tf` | Added `db_name`, `db_username`, `db_password` (sensitive, **no default — you set this**), `db_instance_class` (default `db.t3.micro`), `db_allocated_storage`. |
| `terraform/outputs.tf` | Added `rds_endpoint`, `rds_secret_arn`, `backend_irsa_role_arn`. |
| `terraform/terraform.tfvars.example` | Added RDS vars with a note on how to pass the password. |
| `backend/go.mod` | Swapped `gorm.io/driver/mysql` → `gorm.io/driver/postgres`; added AWS SDK v2 (`config`, `secretsmanager`). |
| `backend/internal/database/secrets.go` | **New.** Fetches DB credentials JSON from Secrets Manager using IRSA-provided AWS credentials. |
| `backend/internal/database/db.go` | Uses Postgres driver; fetches creds from Secrets Manager if `DB_SECRET_ARN` is set, otherwise falls back to plain env vars (local dev). |
| `backend/internal/models/*.go` | **Unchanged** — GORM tags are dialect-agnostic. |
| `docker-compose.yml` | `mysql:8.0` → `postgres:16-alpine`, port 5432, `pg_isready` healthcheck, `DB_SSLMODE=disable` for local. |
| `helm/shopverse/templates/mysql-*.yaml` | **Deleted** (statefulset, service, pvc). |
| `helm/shopverse/templates/serviceaccount.yaml` | **New.** Backend `ServiceAccount` with the IRSA role annotation. |
| `helm/shopverse/templates/configmap.yaml` | Now holds `DB_SECRET_ARN`, `AWS_REGION`, `DB_SSLMODE` instead of MySQL host/user. |
| `helm/shopverse/templates/secret.yaml` | Dropped `DB_PASSWORD` / `MYSQL_ROOT_PASSWORD`; keeps `JWT_SECRET` only. |
| `helm/shopverse/templates/backend-deployment.yaml` | Added `serviceAccountName: shopverse-backend`; removed `DB_PASSWORD` env. |
| `helm/shopverse/values.yaml` | Removed `mysql:` block; added `rds.secretArn`, `aws.region`, `backend.irsaRoleArn`. |
| `.github/workflows/deploy.yaml` | Terraform Init/Setup now always run (needed to read outputs on every deploy); Plan/Apply pass `db_instance_class` and `TF_VAR_db_password`; new step captures `rds_secret_arn` / `backend_irsa_role_arn`; Helm deploy sets those instead of MySQL passwords. |

## What you need to do manually

1. **Set the master password** — it's intentionally not committed anywhere. Two options:
   - Local/manual `terraform apply`: `export TF_VAR_db_password="your-strong-password"` before running `terraform apply` in `terraform/`.
   - CI: add a repo secret named `DB_MASTER_PASSWORD` in GitHub (Settings → Secrets and variables → Actions). The workflow already wires it to `TF_VAR_db_password`.
   - You can also remove the two `MYSQL_ROOT_PASSWORD` / `MYSQL_PASSWORD` GitHub secrets — they're no longer used anywhere.

2. **Regenerate `go.sum`** — this sandbox has no network access, so `backend/go.sum` was left as-is (it still has the old mysql-driver checksums, harmless but stale). Run once, locally or let CI's existing `go mod tidy` step handle it:
   ```bash
   cd backend
   go mod tidy
   ```

3. **First-time apply** — since this adds a new Terraform module, run `terraform plan`/`apply` once yourself (or let the pipeline do it) so the RDS instance and Secrets Manager secret get created. Note: the CI pipeline only runs Terraform when the EKS cluster doesn't exist yet. If your EKS cluster already exists, run `terraform apply` manually once from your machine (with `TF_VAR_db_password` set) so the RDS module gets created — after that, the pipeline will keep reading its outputs on every deploy.

4. **Data migration** — this only migrates the *infrastructure and connection code*. If you have existing data in the old MySQL instance/StatefulSet you want to keep, export it (`mysqldump`) and re-import into Postgres (e.g. via `pgloader`, which converts MySQL dumps to Postgres directly) before cutting the app over. A fresh install will just auto-migrate the schema via GORM and reseed sample products.

5. **DNS/cutover** — once `terraform apply` succeeds and `helm upgrade` deploys the new backend, verify `/health` and a couple of API calls against the new RDS instance before decommissioning the old MySQL StatefulSet's PVC (data is gone once you delete it, so don't rush this if there's real user data).
