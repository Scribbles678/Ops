# Rancher Deployment Guide

Deploy the Operations Scheduling app to a Rancher-managed Kubernetes cluster.

---

## TL;DR

**Two containers, four steps, no manual SQL, no seed scripts.**

1. Build & push the app image
2. Deploy Postgres workload (empty DB — the app will set itself up)
3. Deploy the app workload with 4 env vars
4. Point an Ingress at the app service

Open the URL → log in as **`admin@example.com` / `admin123`** → change the password.

Total deploy time: ~10 minutes. No scripts to run, no SQL to paste.

---

## Part 1 — Deployment Steps

### Prerequisites

- [ ] Rancher access and a namespace to deploy into
- [ ] A container registry the cluster can pull from (Harbor, Docker Hub, etc.)
- [ ] Docker on your local machine to build the image

### Step 1: Build & push the image

From the `scheduling-app-v2/` folder:

```bash
docker build -t your-registry.example.com/scheduling-app:latest .
docker push your-registry.example.com/scheduling-app:latest
```

### Step 2: Deploy Postgres

In Rancher, create a **Workload** called `scheduling-db`:

| Setting | Value |
|---------|-------|
| Image | `postgres:16-alpine` |
| Port | `5432` (TCP) |
| Volume mount | PVC ≥ 5 GB mounted at `/var/lib/postgresql/data` |

Environment variables:

| Variable | Value |
|----------|-------|
| `POSTGRES_USER` | `postgres` |
| `POSTGRES_PASSWORD` | *(strong password)* |
| `POSTGRES_DB` | `scheduling` |

> You do **not** need to run any SQL manually — the app will create everything on first boot.

### Step 3: Deploy the app

Create a **Workload** called `scheduling-app`:

| Setting | Value |
|---------|-------|
| Image | `your-registry.example.com/scheduling-app:latest` |
| Port | `3000` (TCP) |
| Replicas | `1` |
| Health check | HTTP GET `/api/health` on port 3000 |

Environment variables (all go on the **app** workload):

| Variable | Required | Value |
|----------|----------|-------|
| `DATABASE_URL` | **yes** | `postgresql://postgres:YOUR_DB_PASSWORD@scheduling-db:5432/scheduling` |
| `DATABASE_SSL` | **yes** | `false` |
| `JWT_SECRET` | **yes** | Generate: `openssl rand -base64 32` |
| `NODE_ENV` | **yes** | `production` |
| `ADMIN_EMAIL` | optional | Override the default admin login email |
| `ADMIN_PASSWORD` | optional | Override the default admin initial password |
| `ADMIN_NAME` | optional | Display name in the UI (default: `Admin User`) |

On first startup the app will:
1. Create the database schema.
2. Apply all migrations.
3. Create a super-admin user.

### Default initial login

If you **don't** set `ADMIN_EMAIL` / `ADMIN_PASSWORD`, the bootstrap creates a default admin:

- **Email:** `admin@example.com`
- **Password:** `admin123`

This guarantees the app has a working login on first deploy. The pod logs print a warning reminding you to change it immediately via **Settings → Change Password** after the first login.

If you prefer to set your own initial credentials, set the `ADMIN_*` env vars before first boot — the bootstrap uses them instead of the defaults. The env vars are only read when `user_profiles` is empty; after any user exists they're ignored.

Watch the pod logs — you should see lines like:
```
[bootstrap] no schema detected — applying setup.sql
[bootstrap]   ✓ base schema created
[bootstrap] applying 7 migration(s)
[bootstrap]   ✓ 001-add-staffing-targets.sql
...
[bootstrap]   ✓ first super admin created: admin@yourcompany.com
[bootstrap] done
```

### Step 4: Set up the ingress

In Rancher → **Service Discovery** → **Ingresses**:

| Setting | Value |
|---------|-------|
| Host | e.g. `scheduling.yourcompany.local` (ask IT for the right hostname) |
| Path | `/` |
| Target service | `scheduling-app` |
| Port | `3000` |

Open the hostname in a browser and log in with the `ADMIN_EMAIL` / `ADMIN_PASSWORD` values.

**You're done.**

---

## Updating the App

```bash
docker build -t your-registry.example.com/scheduling-app:latest .
docker push your-registry.example.com/scheduling-app:latest
```

Then in Rancher → `scheduling-app` workload → **Redeploy**.

Any new migrations ship with the image and are applied automatically on startup. No manual SQL, no re-seeding.

---

## Troubleshooting

### App won't start / keeps restarting
- **Check the pod logs in Rancher** — the bootstrap plugin logs exactly what it did or which step failed
- Most common cause: `DATABASE_URL` is wrong or the DB pod isn't reachable
- If logs say `[bootstrap] FAILED: ...`, the SQL error message will be right there

### "Connection refused" to database
- Verify the DB pod is running (Rancher → Workloads → `scheduling-db`)
- The hostname in `DATABASE_URL` must match the DB's service name exactly (`scheduling-db`)
- Both workloads must be in the **same namespace**

### Can't log in
- Check the app pod logs for `[bootstrap]` lines — did it say it created the admin?
- If it says `no users exist, but ADMIN_EMAIL / ADMIN_PASSWORD env vars not set`, set them and restart the pod
- If a user exists but with wrong credentials, log in as super admin and reset their password in **Settings → User Management** (or connect to the DB and run an `UPDATE user_profiles SET password_hash = ... WHERE email = ...`)

### Bootstrap skipped migrations
- Migration files must be in `sql-schema/migrations/` inside the image
- Confirm the build included them: `docker run --rm your-registry.example.com/scheduling-app:latest ls sql-schema/migrations` (in a debug shell)

### App is slow or unresponsive
- Check pod resource limits — app needs at least 256 MB RAM
- Check DB performance under load

---

## Environment Variable Reference

| Variable | Required | Purpose |
|----------|----------|---------|
| `DATABASE_URL` | **yes** | Postgres connection string |
| `DATABASE_SSL` | no | `false` for in-cluster DB, `true` for managed DB with TLS |
| `JWT_SECRET` | **yes** | 32+ random chars for signing login tokens |
| `NODE_ENV` | recommended | `production` in prod |
| `ADMIN_EMAIL` | optional | Override default admin email (`admin@example.com`). First-deploy only. |
| `ADMIN_PASSWORD` | optional | Override default admin password (`admin123`). First-deploy only. |
| `ADMIN_NAME` | optional | Display name for the admin (default: `Admin User`) |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` / `SMTP_FROM` | optional | For password-reset emails |
| `APP_URL` | optional | Used in password-reset email links |

`ADMIN_*` vars only matter the first time the app starts with an empty `user_profiles` table. After the admin is created they're ignored and can be removed.

---

## Security Checklist

Before going live with real data:

- [ ] `JWT_SECRET` is a unique random string (not a dev default)
- [ ] `POSTGRES_PASSWORD` is strong
- [ ] `ADMIN_PASSWORD` was changed after first login (Settings → Change Password)
- [ ] DB is not exposed outside the cluster (only the app pod should reach it)
- [ ] Ingress uses HTTPS (cert-manager or your corp cert)
- [ ] PVC snapshots or a `pg_dump` CronJob for regular backups

---

## Quick Reference

| What | Where |
|------|-------|
| App URL | `http://your-hostname` (via ingress) |
| Health check | `GET /api/health` |
| Default login | `admin@example.com` / `admin123` (change immediately after first login) |
| Schema source | `sql-schema/setup.sql` + `sql-schema/migrations/*.sql` (bundled in image) |
| Bootstrap logic | `server/plugins/bootstrap.ts` |
| Auth flow | JWT in HttpOnly cookie, validated by `server/middleware/auth.ts` |
| All data lives in | the `scheduling-db` Postgres pod's PVC |

---

## Part 2 — Architecture Reference (for IT Q&A)

Use this section to answer infrastructure questions from whoever manages the cluster.

### What is this app?

A self-hosted web application for scheduling distribution-center employees. It is a single-page Vue 3 / Nuxt 4 UI plus a Nitro (Node.js) API server, backed by a single PostgreSQL 16 database. All data stays inside your infrastructure — no third-party services, no external API calls.

### Container images

The deployment uses **two container images total**:

| Image | Source | Purpose |
|-------|--------|---------|
| `scheduling-app` | Built in-house from this repo's `Dockerfile` | The full application: web UI + API server. One image, one container. |
| `postgres:16-alpine` | Official Docker Hub image | The database. |

There is no separate frontend image, no reverse proxy image, no worker image, no cache image. Just the app and a database.

### How the app interacts with the database

- The app connects to Postgres via a connection string (`DATABASE_URL`) over TCP port 5432.
- Uses the `pg` Node.js library directly — **no ORM**, no migrations framework. Queries are plain parameterized SQL in the API route handlers.
- A connection pool (max 10 connections) is held inside each app pod.
- **On container startup**, the app runs a self-bootstrap routine (`server/plugins/bootstrap.ts`) that:
  1. Creates the schema if the database is empty (from `sql-schema/setup.sql`).
  2. Applies any pending migrations (files in `sql-schema/migrations/*.sql`, in filename order). All are idempotent.
  3. Creates the first super-admin user if there are zero users, using the `ADMIN_EMAIL` / `ADMIN_PASSWORD` env vars (falls back to `admin@example.com` / `admin123`).
  Safe to re-run — uses Postgres advisory locks to prevent races and `IF NOT EXISTS` / `ON CONFLICT DO NOTHING` guards.

### Request flow

```
Browser ──HTTPS──▶ Rancher Ingress ──▶ scheduling-app pod (port 3000)
                                                   │
                                                   │ pg wire protocol (5432)
                                                   ▼
                                         scheduling-db pod (Postgres 16)
                                                   │
                                                   ▼
                                         Persistent Volume (PVC)
```

- Web UI assets are served by the same container that serves the API — they're bundled together by Nuxt at build time.
- Auth is custom JWT (not OAuth / not SSO). Tokens live in HttpOnly cookies with 8-hour expiry.
- **No outbound network calls** except the database. (Optional SMTP for password-reset emails if you configure it.)

### Resource footprint

| Component | CPU | RAM | Disk |
|-----------|-----|-----|------|
| App pod | ~0.1 core idle, bursts to 0.5 during schedule generation | 256-512 MB | ephemeral |
| DB pod | ~0.05 core idle | 256-512 MB | 5-10 GB PVC typical |

Scales fine to ~100 concurrent users on a single app pod. Horizontal scaling works (stateless pods), though the DB stays single-instance.

### Persistence

- **All data** lives in Postgres. No files on disk.
- Back up the Postgres PVC (volume snapshot, `pg_dump` CronJob, etc.) — that's the full backup.
- App pods are stateless and can be killed/restarted without data loss.

### Network requirements

- Ingress traffic on port 80/443 to the app's port 3000
- Internal cluster traffic on port 5432 (app pod → db pod), same namespace
- **No outbound internet access required** (unless you enable SMTP for password resets)

### Security posture

- JWT secret is a runtime env var (`JWT_SECRET`, 32+ chars — generate with `openssl rand -base64 32`)
- Passwords are bcrypt-hashed in the DB
- All API routes go through `server/middleware/auth.ts` which validates the JWT cookie
- Multi-tenant isolation enforced in the API layer via `team_id` pulled from the signed JWT payload
- Non-root container user (uid 1001, defined in Dockerfile)
- Rate-limited at the API layer (default 200 req/min, stricter for auth endpoints)

### Updates

Build a new image → push to registry → Redeploy the `scheduling-app` workload. The bootstrap on startup picks up any new migrations automatically. **No manual SQL needed on updates.**
