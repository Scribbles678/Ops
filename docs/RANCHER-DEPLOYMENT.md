# Rancher Deployment Guide

Notes, questions, and checklist for deploying the Operations Scheduling app to Rancher in your work network.

---

## Overview

Rancher typically runs Kubernetes. Your app uses Docker Compose locally with three components:

- **app** – Nuxt API server
- **db** – PostgreSQL database
- **seed** – One-time script to create the first admin user

In Rancher you'll need to deploy the app image + PostgreSQL (or a managed database) + run the seed script once.

---

## First-Time Setup: Yes, You Need the Seed Script

With a **fresh database**, you must run the seed script **once** to create the initial admin account:

- Creates "Default Team"
- Creates super admin user (default: `admin@example.com` / `admin123`)

If a user with that email already exists, the script safely skips.

---

## Deployment Flow

### 1. Build and Push Your Image

```powershell
# Build the app image
docker build -t your-registry/scheduling-app:latest .

# Push to the registry your work uses (Docker Hub, private registry, etc.)
docker push your-registry/scheduling-app:latest
```

You'll need the registry URL from your IT team.

### 2. Deploy in Rancher

You (or IT) will deploy in Rancher:

- **App**: Deployment using your image, with env vars (see [Environment Variables](#environment-variables))
- **Database**: Either a Postgres workload or a managed database instance
- **Schema**: Run `sql-schema/setup.sql` against the database before the app starts

### 3. Run the Seed Script Once

After the database is up and the schema is applied, run the seed script **once**. In Kubernetes/Rancher this is typically:

- A **Job** that runs the seed container and exits, or
- A one-off pod that executes `node scripts/seed-first-user.js`

**Seed script environment variables:**

| Variable       | Description                        | Default           |
|----------------|------------------------------------|-------------------|
| `DATABASE_URL` | Same connection string as the app  | (required)        |
| `ADMIN_EMAIL`  | First admin login email            | `admin@example.com` |
| `ADMIN_PASSWORD` | First admin password            | `admin123`        |
| `ADMIN_NAME`   | Display name for the admin user    | `Admin User`      |

---

## Environment Variables

### App Container

| Variable       | Description                         | Production Notes                          |
|----------------|-------------------------------------|-------------------------------------------|
| `DATABASE_URL` | PostgreSQL connection string        | Use production DB credentials             |
| `DATABASE_SSL` | `"true"` or `"false"`               | `"true"` for managed/cloud databases      |
| `JWT_SECRET`   | Secret for signing JWTs             | Use a strong random string (32+ chars)    |
| `NODE_ENV`     | `production` or `development`       | Use `production` in production            |

### Production Security Checklist

- [ ] Set `JWT_SECRET` to a long random string (32+ characters)
- [ ] Use a strong `ADMIN_PASSWORD` (or set via env when running the seed job)
- [ ] Set `NODE_ENV=production`
- [ ] Ensure `DATABASE_URL` uses secure credentials and SSL if applicable

---

## Questions for IT / Rancher Admin

Before deploying, get answers to:

1. **Container registry** – Where should the app image be pushed? (Docker Hub, Harbor, AWS ECR, internal registry, etc.)
2. **PostgreSQL** – Is there a managed database, or should we deploy Postgres as a workload?
3. **Secrets management** – How are credentials stored? (Rancher secrets, HashiCorp Vault, etc.)
4. **Ingress / access** – How will users reach the app? (Hostname, path, load balancer URL)

---

## Seed Script Location

The seed script lives at:

```
scripts/seed-first-user.js
```

It can be run with:

```bash
node scripts/seed-first-user.js
```

Requires `DATABASE_URL` in the environment (or defaults to `postgresql://postgres:postgres@localhost:5432/scheduling`).

---

## Schema Setup

Before running the app or seed script, the database schema must be applied. Run:

```
sql-schema/setup.sql
```

against the target PostgreSQL database.

---

## To-Do

- [ ] **Email provider for password reset** – Configure SMTP (e.g., company email, Resend, SendGrid) so users can reset their own password via the "Forgot your password?" link. Without this, admins must reset passwords manually from Settings or Admin Users.

---

## Summary

| Topic                    | Answer                                                                 |
|--------------------------|------------------------------------------------------------------------|
| Start fresh?             | Yes, if deploying to a new database.                                  |
| Run first-time user script? | Yes, once, after the database and schema are ready.                |
| How?                     | Run the seed script (or equivalent Job/pod) with the env vars above. |
