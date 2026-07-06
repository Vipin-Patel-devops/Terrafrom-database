# Hotel Booking DevOps Assessment — Terraform + Database Reliability

This repo contains:
1. Terraform infrastructure design for `Internet → ALB → ECS/Fargate → RDS`
2. Two Terraform environments (`dev`, `prod`) with different sizing/backup/protection settings
3. A GitHub Actions workflow that runs `fmt` / `init` / `validate` / `plan` on pull requests
4. A local, Docker-based PostgreSQL setup with migrations, seed data, an optimized query, and backup/restore scripts

No AWS deployment is required to complete or review this. Everything in Part 4–6 runs entirely on your machine via Docker.

---

## Repo layout

```
infra/
  modules/
    network/   -> VPC, public+private subnets, IGW, NAT gateway(s), routing
    ecs/       -> ALB, ALB/ECS security groups, ECS cluster, Fargate task+service
    rds/       -> RDS instance + security group (ingress only from ECS SG)
  envs/
    dev/       -> smaller sizing, 3-day backup retention, deletion_protection=false
    prod/      -> larger sizing, 30-day backup retention, deletion_protection=true, multi-AZ
db/
  init/
    001_create_tables.sql   -> schema + indexes (runs first)
    002_seed_data.sql       -> 300 seeded bookings + events (runs second)
scripts/
  backup.sh    -> timestamped pg_dump
  restore.sh   -> restores into a fresh DB and verifies row counts match
docker-compose.yml
.github/workflows/terraform.yml
```

---

## Part 1 & 2 — Terraform infrastructure

### Architecture

- A VPC with 2 public and 2 private subnets across 2 AZs.
- An Internet Gateway for the public subnets, and NAT Gateway(s) so private
  subnets have outbound internet access (needed to pull container images)
  without being reachable from the internet inbound.
- An ALB in the public subnets, receiving HTTP traffic from the internet.
- ECS/Fargate tasks in the **private** subnets, only reachable from the ALB's
  security group (`aws_security_group.ecs` only allows ingress from `aws_security_group.alb`).
- RDS in the **private** subnets, only reachable from the ECS security group
  (`aws_security_group.rds` only allows ingress from the ECS SG) — RDS has
  `publicly_accessible = false` and no route to the internet.

### Environment differences (dev vs prod)

| Setting | dev | prod |
|---|---|---|
| Task CPU/Memory | 256 / 512 | 1024 / 2048 |
| Desired task count | 1 | 2 |
| RDS instance class | db.t3.micro | db.r6g.large |
| RDS backup retention | 3 days | 30 days |
| RDS deletion protection | false | true |
| RDS Multi-AZ | false | true |
| NAT gateways | 1 shared | 1 per AZ |
| Backend state key | `hotel-booking/dev/...` | `hotel-booking/prod/...` |

Each environment (`infra/envs/dev`, `infra/envs/prod`) has its own
`variables.tf`, `terraform.tfvars`, and inline S3 backend block in `main.tf`
(bucket/table names are placeholders — replace `REPLACE-ME-...` with real
resources if you ever deploy for real).

### How to validate locally (no AWS account needed for this much)

```bash
cd infra/envs/dev      # or infra/envs/prod
terraform fmt -check -recursive ../../
terraform init -backend=false      # skips remote state, just wires up providers/modules
terraform validate
```

### How to produce a real plan (requires AWS credentials)

```bash
cd infra/envs/dev
# create the S3 bucket + DynamoDB table referenced in main.tf's backend block,
# or comment the backend block out to use local state for a dry run
terraform init
export TF_VAR_db_password="something-strong"
terraform plan -refresh=false
```

We never commit the DB password to `terraform.tfvars` — it's passed via the
`TF_VAR_db_password` environment variable (or a CI secret).

---

## Part 3 — GitHub Actions Terraform workflow

`.github/workflows/terraform.yml` runs on every PR that touches `infra/**`:
- `terraform fmt -check`
- `terraform init` (in `-backend=false` mode by default, so it works without
  any AWS credentials or a pre-created backend)
- `terraform validate`
- `terraform plan` — this step only runs if `AWS_ACCESS_KEY_ID` /
  `AWS_SECRET_ACCESS_KEY` repo secrets are configured. When present, the
  plan output is both uploaded as a workflow artifact and posted as a PR
  comment.

To enable the full plan step, add these repository secrets in
GitHub → Settings → Secrets and variables → Actions:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `TF_VAR_DB_PASSWORD`

---

## Part 4 — Local database

```bash
docker compose up -d
```

This starts Postgres 16 on `localhost:5432` (db: `hotel_bookings`, user:
`hotel_admin`, password: `hotel_pass`) and automatically runs, in order:
1. `db/init/001_create_tables.sql` — creates `hotel_bookings` and `booking_events`, plus indexes
2. `db/init/002_seed_data.sql` — inserts 300 bookings across 5 orgs, 6 cities, 4 statuses, with events for ~70% of bookings

Verify it came up correctly:
```bash
docker exec -it hotel_bookings_db psql -U hotel_admin -d hotel_bookings -c "SELECT COUNT(*) FROM hotel_bookings;"
docker exec -it hotel_bookings_db psql -U hotel_admin -d hotel_bookings -c "SELECT COUNT(*) FROM booking_events;"
```

---

## Part 5 — Query optimization

Target query:
```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

### Indexing decision

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

**Why this index:**
- The `WHERE` clause filters on `city` (equality) and `created_at` (range).
  Putting `city` first and `created_at` second in a composite B-tree index
  lets Postgres do a single index range scan straight to the matching rows
  — `city = 'delhi'` narrows to a contiguous slice of the index, and within
  that slice `created_at >= ...` is another contiguous range.
- Without this index, Postgres has to sequentially scan the whole table
  and filter every row, which gets worse as the table grows.
- The `INCLUDE (org_id, status, amount)` clause adds those columns to the
  index leaf pages without making them part of the sort key. Since those
  are exactly the columns the query needs for its `SELECT`/`GROUP BY`,
  Postgres can answer the entire query as an **index-only scan** — it
  never has to fetch the underlying table rows (the "heap") at all, as
  long as the visibility map is up to date (i.e., table is regularly
  vacuumed, which is Postgres's default autovacuum behavior).

Confirm it's being used:
```bash
docker exec -it hotel_bookings_db psql -U hotel_admin -d hotel_bookings -c "
EXPLAIN ANALYZE
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;"
```
You should see `Index Only Scan using idx_hotel_bookings_city_created_at` in the plan.

---

## Part 6 — Backup and restore

```bash
./scripts/backup.sh
```
Creates `backups/hotel_bookings_<timestamp>.dump` (custom-format `pg_dump`,
so it's compressed and works with `pg_restore`), and updates a
`backups/latest.dump` symlink to point at it.

```bash
./scripts/restore.sh
```
Restores the latest backup into a **separate, freshly-created** database
called `hotel_bookings_restore_test` inside the same container (so your
original data is never touched), then automatically compares row counts
between the original and restored `hotel_bookings` tables and prints
SUCCESS/WARNING accordingly.

You can also verify manually:
```bash
docker exec -it hotel_bookings_db psql -U hotel_admin -d hotel_bookings_restore_test -c "SELECT COUNT(*) FROM hotel_bookings;"
docker exec -it hotel_bookings_db psql -U hotel_admin -d hotel_bookings_restore_test -c "SELECT COUNT(*) FROM booking_events;"
```
Both counts should match the original database.

To restore a specific backup file instead of the latest one:
```bash
./scripts/restore.sh backups/hotel_bookings_20260706_120000.dump
```

---

## Full local verification checklist

```bash
# Database
docker compose up -d
docker exec -it hotel_bookings_db psql -U hotel_admin -d hotel_bookings -c "SELECT COUNT(*) FROM hotel_bookings;"
./scripts/backup.sh
./scripts/restore.sh

# Terraform (per environment)
cd infra/envs/dev
terraform fmt -check -recursive ../../
terraform init -backend=false
terraform validate
cd ../prod
terraform init -backend=false
terraform validate
```
