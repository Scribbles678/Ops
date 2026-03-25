# Rancher Deployment Guide

Step-by-step instructions for deploying the Operations Scheduling app to a Rancher-managed Kubernetes cluster on your work network.

---

## What You're Deploying

The app has two pieces that need to run:

1. **App container** - The Nuxt web server (serves the UI and API)
2. **PostgreSQL database** - Stores all your data (employees, schedules, etc.)

Plus a one-time **seed script** that creates your first admin login.

---

## Prerequisites

Before you start, make sure you have:

- [ ] Access to your Rancher dashboard (the web UI where you manage containers)
- [ ] A container registry your Rancher cluster can pull from (ask IT — could be Harbor, Docker Hub, AWS ECR, etc.)
- [ ] Docker installed on your local machine (for building the image)
- [ ] The registry URL and any login credentials for pushing images

---

## Step 1: Build the Docker Image

Open a terminal in the project folder (`scheduling-app-v2/`) and run:

```powershell
# Build the image (this compiles the app for production)
docker build -t your-registry.example.com/scheduling-app:latest .
```

Replace `your-registry.example.com` with the actual registry URL from your IT team.

This takes 1-3 minutes. When it finishes you'll see "Successfully built".

---

## Step 2: Push the Image to Your Registry

```powershell
# Log in to your registry (if required)
docker login your-registry.example.com

# Push the image so Rancher can pull it
docker push your-registry.example.com/scheduling-app:latest
```

If your registry uses a different auth method (like a token), IT can help with the login step.

---

## Step 3: Set Up PostgreSQL in Rancher

You need a PostgreSQL 16 database. Two options:

### Option A: Deploy Postgres as a Workload (simplest)

In Rancher, create a new **Workload** (Deployment):

| Setting | Value |
|---------|-------|
| Name | `scheduling-db` |
| Image | `postgres:16-alpine` |
| Port | `5432` (TCP) |

Add these **environment variables**:

| Variable | Value |
|----------|-------|
| `POSTGRES_USER` | `postgres` |
| `POSTGRES_PASSWORD` | (pick a strong password) |
| `POSTGRES_DB` | `scheduling` |

Add a **persistent volume** mounted at `/var/lib/postgresql/data` so your data survives restarts. In Rancher this is under "Volumes" when editing the workload — create a Persistent Volume Claim (PVC) with at least 5GB.

### Option B: Use an Existing Database

If your org already has a managed Postgres instance, just get the connection string from your DBA and skip to Step 4.

---

## Step 4: Create the Database Schema

You need to run the schema SQL **once** against your new database. This creates all the tables.

**From Rancher:** Open the shell for your `scheduling-db` pod (click the pod → Execute Shell), then run:

```bash
psql -U postgres -d scheduling
```

This opens the Postgres prompt. Now copy-paste the **entire contents** of `sql-schema/setup.sql` into the terminal and press Enter. You should see a series of `CREATE TABLE`, `CREATE INDEX`, etc. messages.

Then also run the staffing targets table (this is new and not yet in setup.sql):

```sql
CREATE TABLE IF NOT EXISTS public.staffing_targets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_function_id uuid NOT NULL,
  hour_start time WITHOUT TIME ZONE NOT NULL,
  headcount integer NOT NULL DEFAULT 0,
  is_active boolean DEFAULT true,
  team_id uuid NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT staffing_targets_pkey PRIMARY KEY (id),
  CONSTRAINT staffing_targets_unique UNIQUE (job_function_id, hour_start, team_id),
  CONSTRAINT staffing_targets_job_function_fkey FOREIGN KEY (job_function_id) REFERENCES job_functions(id) ON DELETE CASCADE,
  CONSTRAINT staffing_targets_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  CONSTRAINT check_headcount_positive CHECK (headcount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_staffing_targets_team ON public.staffing_targets USING btree (team_id);
```

Type `\q` to exit psql when done.

---

## Step 5: Run the Seed Script (First-Time Only)

The seed script creates your first admin user so you can log in. You only need to do this **once**.

**From Rancher**, create a one-time **Job** (not a Deployment):

| Setting | Value |
|---------|-------|
| Name | `scheduling-seed` |
| Image | `your-registry.example.com/scheduling-app:latest` |
| Command | `node` |
| Args | `scripts/seed-first-user.js` |
| Restart Policy | `Never` |

> **Note:** The seed container uses the same image as the app — it has the seed script built in. Override the command to run the script instead of starting the web server.

Add these **environment variables**:

| Variable | Value | Notes |
|----------|-------|-------|
| `DATABASE_URL` | `postgresql://postgres:YOUR_PASSWORD@scheduling-db:5432/scheduling` | Replace `YOUR_PASSWORD` and `scheduling-db` with your actual DB service name |
| `DATABASE_SSL` | `false` | Use `true` if connecting to an external/managed DB with SSL |
| `ADMIN_EMAIL` | Your email (e.g. `mike@company.com`) | This is your login |
| `ADMIN_PASSWORD` | Pick a strong password | You can change this later in the app |
| `ADMIN_NAME` | Your name (e.g. `Mike Johnson`) | Display name in the app |

The job will run, create the admin user, and exit. Check the logs to confirm it says "Admin user created" (or "already exists" if you run it again — it's safe to re-run).

---

## Step 6: Deploy the App

In Rancher, create a new **Workload** (Deployment):

| Setting | Value |
|---------|-------|
| Name | `scheduling-app` |
| Image | `your-registry.example.com/scheduling-app:latest` |
| Port | `3000` (TCP) |
| Replicas | `1` (can increase later) |

Add these **environment variables**:

| Variable | Value | Notes |
|----------|-------|-------|
| `DATABASE_URL` | `postgresql://postgres:YOUR_PASSWORD@scheduling-db:5432/scheduling` | Same as the seed script |
| `DATABASE_SSL` | `false` | `true` for external/managed DBs |
| `JWT_SECRET` | A random string, 32+ characters | Used to sign login tokens. Generate one: `openssl rand -base64 32` |
| `NODE_ENV` | `production` | |

The container has a built-in health check at `/api/health` — Rancher will use this to know when the app is ready.

---

## Step 7: Set Up Ingress (Make It Accessible)

To access the app from your browser, you need an **Ingress** rule in Rancher:

1. Go to **Service Discovery** > **Ingresses** in your namespace
2. Create a new Ingress:
   - **Name**: `scheduling-app`
   - **Host**: The hostname you want (e.g. `scheduling.yourcompany.local`)
   - **Path**: `/`
   - **Target Service**: `scheduling-app`
   - **Port**: `3000`

Ask IT what hostname/domain to use — they may need to add a DNS record pointing to the Rancher cluster's load balancer IP.

Once the ingress is active, open `http://scheduling.yourcompany.local` in your browser and log in with the admin credentials you set in Step 5.

---

## Updating the App (Future Deployments)

When you have a new version to deploy:

```powershell
# Rebuild with your changes
docker build -t your-registry.example.com/scheduling-app:latest .

# Push to registry
docker push your-registry.example.com/scheduling-app:latest
```

Then in Rancher, go to the `scheduling-app` workload and click **Redeploy**. It will pull the new image and restart.

No need to re-run the seed script or schema unless the update instructions say so.

---

## Troubleshooting

### App won't start / keeps restarting
- Check the pod logs in Rancher (click the pod → View Logs)
- Most common cause: `DATABASE_URL` is wrong or the DB isn't reachable
- Verify the DB service name matches what's in your `DATABASE_URL`

### "Connection refused" to database
- Make sure the Postgres workload is running and healthy
- The DB service name in `DATABASE_URL` must match the Rancher service name exactly (e.g. `scheduling-db`)
- Both workloads must be in the **same namespace**

### Can't log in
- Verify the seed script ran successfully (check its job logs)
- Make sure you're using the email/password you set in the seed environment variables
- Default credentials if you didn't customize: `admin@example.com` / `admin123`

### Schema errors or missing tables
- Re-run `setup.sql` against the database (see Step 4)
- Check that the `staffing_targets` table was also created

### App is slow or unresponsive
- Check pod resource limits in Rancher — the app needs at least 256MB RAM
- Check Postgres performance — add more memory to the DB pod if needed

---

## Security Checklist

Before going live with real data:

- [ ] Change `JWT_SECRET` to a unique random string (not the dev default)
- [ ] Change the admin password from the default after first login
- [ ] Use a strong `POSTGRES_PASSWORD`
- [ ] Restrict network access to the database (only the app should connect)
- [ ] Set up regular database backups (Rancher can schedule volume snapshots, or use `pg_dump` via a CronJob)

---

## Quick Reference

| What | Where |
|------|-------|
| App URL | `http://your-hostname:3000` (or via ingress) |
| Health check | `GET /api/health` |
| App image | Built from `Dockerfile` in project root |
| Schema file | `sql-schema/setup.sql` |
| Seed script | `scripts/seed-first-user.js` |
| Default login | `admin@example.com` / `admin123` (change these!) |
