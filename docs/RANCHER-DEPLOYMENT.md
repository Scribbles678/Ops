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

> **New installs: apply `deploy/k8s/` instead** ("For IT" §2 and §3, skipping the
> copy steps). It puts the database on a disk that survives node drains and sets up
> nightly backups. The hand-made workload below is how the first install was done, and
> it lost its data in a node drain in Sep 2026.

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

This guarantees the app has a working login on first deploy. The pod logs print a warning reminding you to change it immediately via **Settings → My account → Change password** after the first login.

If you prefer to set your own initial credentials, set the `ADMIN_*` env vars before first boot — the bootstrap uses them instead of the defaults. The env vars are only read when `user_profiles` is empty; after any user exists they're ignored.

Watch the pod logs — you should see lines like:
```
[bootstrap] no schema detected — applying setup.sql
[bootstrap]   ✓ base schema created
[bootstrap] applying 21 migration(s)
[bootstrap]   ✓ 001-add-staffing-targets.sql
...
[bootstrap]   ✓ 008-add-missing-columns.sql
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

### Release checklist — the Sep 2026 update (roles, change log, attendance points, UPI)

The migrations (019–022) are all additive and apply themselves. What needs a
person is the data around them. **Before** redeploying, on the work database:

```sql
-- 1. Accounts with NO role: after this update they cannot do anything until a
--    Super Admin assigns one. (Every "Admin" becomes a Supervisor automatically.)
SELECT email FROM user_profiles
WHERE is_active AND NOT is_super_admin AND NOT is_admin AND NOT is_display_user;

-- 2. Accounts with NO team: refused all data (this has been true since Aug 2026).
SELECT email FROM user_profiles WHERE team_id IS NULL AND is_active;

-- 3. Rows with NO team in any data table are invisible to everyone — see TESTING.md.

-- 4. Two dead settings keys that nothing reads (see PTO-AND-REQUESTS.md):
DELETE FROM team_settings
WHERE setting_key IN ('max_leave_early_per_employee_per_day',
                      'max_shift_change_per_employee_per_day');
```

**After** the first boot, in Settings → Users:

1. Open each team lead and change their role from Supervisor to **Team Lead /
   Coordinator** (one dropdown each; applies immediately).
2. Give any no-role account from query 1 a role.
3. Fill in **Full Name** on every account — the change log records names.

Then in Team Setup → Employees & Training, add each employee's **UPI** so they
can check their own requests at the kiosk.

### Release notes — the builder update (late Sep 2026)

One small migration, **023** (adds an empty `job_functions.training_target`). It
applies itself on boot, so there is nothing to run by hand. What supervisors will
notice:

- The **Automated Schedule Builder V2** card is gone; one builder card remains.
- **Required assignments are followed block by block.** "X4 mornings, EM9
  afternoons" used to run X4 all day, so those people's schedules will change —
  that is the fix.
- The first builds may list **things to fix** that were silently skipped before: a
  required block outside the person's shift (often after a shift swap), inside
  their break, on an inactive job, or overlapping another. Each links to where it
  is fixed.
- Building or copying onto a day that already has a schedule **asks first**.
- If anything the builder needs fails to load, it says so and builds nothing,
  instead of building without it.
- **Edit Job Function is shorter** and fits small screens: priority, max people at
  once, "send spare people here first" and Active. Productivity rate, unit,
  "exclude from staffing targets grid" and the two keep-covered boxes are gone
  (none of them changed a build). Saved values stay in the database.
- **TL, coordinator** and any other job that was hidden now appear in the Staffing
  Targets grid, normally as a row of zeros. Hiding a job never stopped its targets
  from being staffed.
- Clearing **Max people at once** now saves as "no limit". It used to fail
  silently while the form closed as if it had saved.
- The **Training & Coverage Preview** is gone from Create Schedule. In its place,
  **Team Setup → Training Matrix** shows how many people trained on each job are
  on shift each hour, with a **training target** per job; hours below the target
  show red. It is not tied to a date.
- **Signing in works on `http://` addresses too.** It used to "succeed" and then
  fail every screen with `401 Unauthorized` (the second site's first user). Still
  ask IT for HTTPS on the ingress, and set `APP_URL` so reset emails link to it.
- **Sessions last while you use the app** and end after 8 hours idle. When one
  ends, a "Your session ended — sign in again" window appears over the page;
  signing back in keeps anything unsaved on screen. No more raw "401" errors.
- **Deactivating someone, or changing their role or team, applies on their next
  click** — no longer at their next sign-in. A lost kiosk can be switched off.
- The wall display only accepts the kiosk account when it asks to sign in.
- Account creation is no longer limited to 5 an hour; a second site's `kiosk@…`
  account gets the username `kiosk2` instead of an error. Change Password says
  "Current password is incorrect" and asks for 8 characters, like the server.
- Changing team in Settings reloads the page (and other open tabs), so the old
  team's request rules can no longer be saved into the new one.

### Release checklist — multi-site readiness (late Sep 2026)

Migration **024** makes the database refuse any row that points at another team's
employee, job function or shift, requires a team on every team table, and adds the
indexes 5–10 sites need. It never deletes or rewrites data: rows that already break
the rule are left alone and the boot log prints a `WARNING` naming the table.

**Before deploying**, run this read-only check on the work database (paste into
`psql` on the `scheduling-db` pod). All zeros means 024 applies cleanly; anything
else, send the numbers over before deploying:

```sql
SET default_transaction_read_only = on;
SELECT 'assignment -> employee' AS link, count(*) AS rows FROM schedule_assignments x JOIN employees p ON p.id = x.employee_id WHERE x.team_id IS DISTINCT FROM p.team_id
UNION ALL SELECT 'assignment -> job', count(*) FROM schedule_assignments x JOIN job_functions p ON p.id = x.job_function_id WHERE x.team_id IS DISTINCT FROM p.team_id
UNION ALL SELECT 'assignment -> shift', count(*) FROM schedule_assignments x JOIN shifts p ON p.id = x.shift_id WHERE x.team_id IS DISTINCT FROM p.team_id
UNION ALL SELECT 'training -> employee', count(*) FROM employee_training x JOIN employees p ON p.id = x.employee_id WHERE x.team_id IS DISTINCT FROM p.team_id
UNION ALL SELECT 'training -> job', count(*) FROM employee_training x JOIN job_functions p ON p.id = x.job_function_id WHERE x.team_id IS DISTINCT FROM p.team_id
UNION ALL SELECT 'employee -> shift', count(*) FROM employees x JOIN shifts p ON p.id = x.shift_id WHERE x.team_id IS DISTINCT FROM p.team_id
UNION ALL SELECT 'time off -> employee', count(*) FROM pto_days x JOIN employees p ON p.id = x.employee_id WHERE x.team_id IS DISTINCT FROM p.team_id
UNION ALL SELECT 'swap -> employee or shifts', count(*) FROM shift_swaps x JOIN employees e ON e.id = x.employee_id JOIN shifts a ON a.id = x.original_shift_id JOIN shifts b ON b.id = x.swapped_shift_id WHERE x.team_id IS DISTINCT FROM e.team_id OR x.team_id IS DISTINCT FROM a.team_id OR x.team_id IS DISTINCT FROM b.team_id
UNION ALL SELECT 'request -> employee', count(*) FROM schedule_requests x JOIN employees p ON p.id = x.employee_id WHERE x.team_id IS DISTINCT FROM p.team_id
UNION ALL SELECT 'required assignment -> employee or job', count(*) FROM preferred_assignments x JOIN employees e ON e.id = x.employee_id JOIN job_functions j ON j.id = x.job_function_id WHERE x.team_id IS DISTINCT FROM e.team_id OR x.team_id IS DISTINCT FROM j.team_id
UNION ALL SELECT 'staffing target -> job', count(*) FROM staffing_targets x JOIN job_functions p ON p.id = x.job_function_id WHERE x.team_id IS DISTINCT FROM p.team_id
UNION ALL SELECT 'attendance point / note / error -> employee', (SELECT count(*) FROM attendance_points x JOIN employees p ON p.id = x.employee_id WHERE x.team_id IS DISTINCT FROM p.team_id) + (SELECT count(*) FROM performance_notes x JOIN employees p ON p.id = x.employee_id WHERE x.team_id IS DISTINCT FROM p.team_id) + (SELECT count(*) FROM performance_errors x JOIN employees p ON p.id = x.employee_id WHERE x.team_id IS DISTINCT FROM p.team_id)
UNION ALL SELECT 'rows with no team', (SELECT count(*) FROM employees WHERE team_id IS NULL) + (SELECT count(*) FROM shifts WHERE team_id IS NULL) + (SELECT count(*) FROM job_functions WHERE team_id IS NULL) + (SELECT count(*) FROM schedule_assignments WHERE team_id IS NULL) + (SELECT count(*) FROM pto_days WHERE team_id IS NULL) + (SELECT count(*) FROM schedule_requests WHERE team_id IS NULL) + (SELECT count(*) FROM employee_training WHERE team_id IS NULL);
```

Also check for overnight shifts, those ending at or before their start. After this
update one can still be deactivated or reactivated, but its edit window won't save
(even just a new name) until its times end after they start. Any listed here need
new times in Team Setup:

```sql
SELECT t.name AS team, s.name AS shift, s.start_time, s.end_time
FROM shifts s JOIN teams t ON t.id = s.team_id
WHERE s.end_time <= s.start_time;
```

**After deploying**, look for `024:` warnings in the app pod's boot log. None means
every team is walled off at the database level too. Then, as a Super Admin:

1. In **Settings → Teams**, set each team's **time zone**. Migration **025**
   starts every team on Central. The zone decides "today" at that site, which drives
   the notice period and past-date checks on requests, the availability strip and the
   display board.
2. Switch to each team (Account Information → Change Team) and check its **Request
   Rules**. A team whose rules were never saved says so at the top of the card. It
   runs on the defaults until then, including a limit of 8 hours of time off per
   day for the whole team.
3. Tell each site's supervisors they now manage their own accounts (below).

What people will notice:

- **Teams can no longer reach each other's data.** Every save that names a person,
  job or shift now checks it belongs to your team — schedules, time off, requests,
  shift swaps, required assignments, targets, attendance points and notes. (Before,
  a request filed with another site's employee was auto-approved into that site.)
- **The kiosk account is limited to the board and requests.** It can no longer
  change schedules, shifts, targets or time off, and no longer sees other people's
  request notes or UPIs.
- **A team can only be deleted when it's empty.** It used to erase the whole site
  after one "are you sure?"; now it lists what the team still holds, and the
  delete button asks you to type the team's name.
- Failed saves say so: Staffing Targets, Required Assignments and PTO Calendar
  approvals no longer show "saved" when they weren't.
- Requests and availability only accept dates within two years of today — a far-off
  date used to freeze the app for every site.
- **Supervisors manage their own site's accounts** in Settings → Users.
  They can add people, change roles, reset passwords and deactivate accounts. They
  can't make anyone a Super Admin, move an account to another site or change a Super
  Admin's account. Creating teams and deleting accounts stay with Super Admins.
- Nobody can deactivate their own account or change their own role, so the last
  Super Admin can't lock themselves out.
- **Each site's "today" follows its time zone.** At 5 pm Pacific the server's clock
  is already on tomorrow, so requests for tomorrow were refused as "same day" and the
  display board turned over early. Both now follow the site's own clock.
- A shift must end after it starts, on the same day: overnight times are refused
  with a message, in the form and by the server. A job named "Lunch", "Break",
  "Break 1" or "Break 2" now keeps its name on the schedule; its hours used to be
  dropped from the day each time it was saved. "Meter Room" is its own job, not a
  meter. Where no numbered meters exist, choosing Meter in the assign window says to
  add "Meter 1", "Meter 2"… in Team Setup; it no longer offers placeholder buttons
  that couldn't save.

---

## For IT — before more sites go live (Sep 2026)

Three things outside the app. None of them needs a new image.

| # | What | Why | Downtime |
|---|---|---|---|
| 1 | HTTPS on the ingress, then `APP_URL` | Sign-ins currently cross the network unencrypted, password included | none |
| 2 | Nightly backups | There are none today. The Sep 2026 data loss had nothing to restore from | none |
| 3 | Move the database onto a durable disk | The hand-made database came back **empty** after a node drain (`DB-DATA-LOSS-INCIDENT.md`) | ~10 minutes, after hours |

Do 2 first: it protects the current data straight away, and 3 uses it. The files are in
`deploy/k8s/` in this repo. The commands below run in Rancher's **Kubectl Shell** (the
`>_` button); Rancher → **Import YAML** works for the files too. The files assume
namespace `ns-operations-scheduler`:

```bash
NS=ns-operations-scheduler
```

The backup and restore scripts, the non-root database container and a clean stop and
restart were tested in Docker against a copy of the development database (Sep 24).
The files pass a schema check for Kubernetes 1.30. They have **not** been applied to a
cluster yet.

### 1. HTTPS on the ingress, and `APP_URL`

The app needs no change for HTTPS. It marks its session cookie (`auth_token`) as
Secure by itself when the request arrived over HTTPS.

1. Give the ingress a certificate for its host. In Rancher that's Service Discovery →
   Ingresses → the app's ingress → Edit → **Certificates**. Use a TLS secret holding
   the company certificate:
   ```bash
   kubectl -n $NS create secret tls scheduling-tls --cert=cert.pem --key=key.pem
   ```
   or, if the cluster runs cert-manager, its issuer annotation. In YAML:
   ```yaml
   spec:
     tls:
       - hosts: [scheduling.example.com]
         secretName: scheduling-tls
   ```
   The ingress controller must pass `X-Forwarded-Proto`. ingress-nginx and Azure
   Application Gateway both do by default, and ingress-nginx then also redirects
   `http://` to `https://`.
2. Check: `https://<host>/api/health` answers 200. After signing in, the browser's dev
   tools (Application → Cookies) show `auth_token` with **Secure** ticked.
3. On the app workload, set `APP_URL=https://<host>` and redeploy. It's the address in
   password-reset emails, which are sent only if the `SMTP_*` variables are set.
   Without SMTP, people ask their supervisor, who resets passwords in Settings → Users.
4. Point the wall displays and everyone's bookmarks at the `https://` address.

### 2. Nightly backups

`deploy/k8s/backup-cronjob.yaml` runs `pg_dump` at 02:00 Central every night onto a
separate Azure Files share (`db-backups-pvc.yaml`). It keeps 30 dailies and 12
Sunday copies. The job **fails**, and shows as failed in Rancher, if the dump is
under 10 KB or has no user accounts in it. Each run's log ends with row counts
(teams, accounts, employees, assignments) that should only ever grow.

1. Once, as cluster-admin: the storage classes. Their disks survive their claim
   being deleted (`reclaimPolicy: Retain`).
   ```bash
   kubectl apply -f deploy/k8s/storageclass.yaml
   ```
2. The database password Secret. Use the password of the **current** database (the
   one in the app's `DATABASE_URL`). The new database in step 3 will use the same one,
   so moving only changes the host name.
   ```bash
   kubectl -n $NS create secret generic scheduling-postgres --from-literal=POSTGRES_PASSWORD='<current password>'
   ```
3. Until the move to the durable disk, back up the **current** database. In
   `backup-cronjob.yaml`, change `PGHOST` to `scheduling-db`, then:
   ```bash
   kubectl apply -f deploy/k8s/db-backups-pvc.yaml -f deploy/k8s/backup-cronjob.yaml
   kubectl -n $NS create job --from=cronjob/scheduling-db-backup backup-now-1
   kubectl -n $NS logs -f job/backup-now-1
   ```
   The log must end `OK: /backups/daily/scheduling-<date>.dump (<size> bytes)`, after
   counts that match the site. From here on there's a backup every night.
4. **Off-cluster copy.** The share lives in an Azure storage account, by default in
   the cluster's node resource group (`MC_…`). Turn on **Azure Backup** for that file
   share (or scheduled share snapshots), so a copy survives losing the cluster too.
   Deleting the cluster's resource group would take both the database and the
   backups with it.

### 3. Move the database onto a durable disk

`db-statefulset.yaml` runs the same `postgres:16-alpine` as a StatefulSet on an Azure
disk (`managed-csi-retain`). Draining the node, deleting the pod or even deleting the
StatefulSet leaves the disk and its data in place. It gets a different name,
`scheduling-postgres`, so the old and new databases can run side by side. Rolling
back is just a matter of changing `DATABASE_URL` back.

After hours:

1. Start the new database (empty for now):
   ```bash
   kubectl apply -f deploy/k8s/db-service.yaml -f deploy/k8s/db-statefulset.yaml
   kubectl -n $NS rollout status statefulset/scheduling-postgres
   kubectl -n $NS get pvc data-scheduling-postgres-0    # Bound, STORAGECLASS managed-csi-retain
   ```
2. Stop the app so nothing changes during the copy (use the app workload's name):
   ```bash
   kubectl -n $NS scale deployment/scheduling-app --replicas=0
   ```
3. A final backup of the old database: as in §2 step 3, with job name `backup-now-2`.
   Note the file name and the counts in its log.
4. Restore it into the new database. In `deploy/k8s/restore-job.example.yaml` set
   `BACKUP_FILE` to `daily/scheduling-<date>.dump` (leave `PGHOST` as
   `scheduling-postgres`). Then:
   ```bash
   kubectl apply -f deploy/k8s/restore-job.example.yaml
   kubectl -n $NS logs -f job/scheduling-db-restore
   ```
   The log must end `RESTORED: …`, after the same counts as step 3.
5. Point the app at the new database. In the app workload's `DATABASE_URL`, change
   the host from `scheduling-db` to `scheduling-postgres` (the rest stays), and scale
   it back to 1. Its log must say `[bootstrap] base schema already present` and
   `user(s) already exist`, **not** `no schema detected`. Sign in and open a recent
   schedule.
6. Back up the new database from now on: set `PGHOST` in `backup-cronjob.yaml` back
   to `scheduling-postgres`, then
   ```bash
   kubectl apply -k deploy/k8s
   kubectl -n $NS delete job backup-now-1 backup-now-2 scheduling-db-restore
   ```
7. **The persistence test.** It's required, and it's the check that would have caught
   the Sep 2026 loss on day one. Note a number in the app (e.g. employees on a team),
   then:
   ```bash
   kubectl -n $NS delete pod scheduling-postgres-0
   kubectl -n $NS rollout status statefulset/scheduling-postgres
   kubectl -n $NS logs scheduling-postgres-0 | grep -c "init process complete"   # must print 0
   ```
   The number in the app must be unchanged. The stronger version is `kubectl drain`
   on the node the pod is on, which is the event that caused the loss.
8. Scale the old `scheduling-db` workload to 0. Keep it and its volume for a week,
   then delete them.

**Rolling back**, any time before step 8's delete: scale the app to 0, set
`DATABASE_URL` back to `scheduling-db`, scale `scheduling-db` up if it was scaled
down, then scale the app up. Anything saved in between exists only in the new database.

### Restoring a backup

1. See what's there: the nightly job's log names each file. Or apply the restore job
   with `BACKUP_FILE` left as the placeholder: it stops without touching anything and
   lists the files.
2. Scale the app to 0. The restore job refuses to start while anything is connected.
3. Set `BACKUP_FILE` in `restore-job.example.yaml`, then apply it and follow its log
   as in §3 step 4. It first saves the current database to `pre-restore-<time>.dump`
   on the share, so restoring the wrong file can be undone. The restore itself is one
   transaction: if any part fails, the database is left as it was.
4. Scale the app to 1 and check. Delete the job. Once you're satisfied, the
   `pre-restore-*.dump` file can go.

Today's data restores in seconds.

**Alternative to §2 and §3:** Azure Database for PostgreSQL (Flexible Server) comes
with its own backups and point-in-time restore. The app needs only a new
`DATABASE_URL` and `DATABASE_SSL=true`. It changes cost and who owns the database,
so that's a platform decision.

---

## Troubleshooting

### App won't start / keeps restarting
- **Check the pod logs in Rancher** — the bootstrap plugin logs exactly what it did or which step failed
- Most common cause: `DATABASE_URL` is wrong or the DB pod isn't reachable
- If logs say `[bootstrap] FAILED: ...`, the SQL error message will be right there, followed by
  `exiting so the pod restarts` — a failed setup restarts the pod on purpose (since Sep 2026)
- `[bootstrap] waiting for the database (...) — retrying` is normal right after a restart: the app
  pod usually comes up before the database and waits. Meanwhile `/api/health` and every API call
  answer 503 "starting up".

### `relation "..." does not exist` in the logs
The app is talking to a database with no tables. Since Sep 2026 it can no longer get there by
starting too early (it waits), so this means the **database was emptied or replaced while the app
was running** — a database pod restarted onto a fresh volume, or a restore in progress.
`GET /api/health` then answers `"tables": "missing"`. The app does not rebuild the tables by
itself, on purpose: that would turn lost data into an empty install that looks healthy. Restore
the data first (see `DB-DATA-LOSS-INCIDENT.md`), **then** restart the app pod — restarting it
against an empty database creates a fresh install with the default admin login.

### Health check
`GET /api/health` answers **503** while the app is starting (waiting for the database or setting
it up) or cannot reach the database, and **200** once it is running — including when the tables
are missing (`"status": "no-tables"`). Deliberately: if it is wired as a *liveness* probe, failing
on missing tables would restart the pod mid-restore and seed a fresh install. As a *readiness*
probe it keeps traffic off the pod while it starts.

### "Connection refused" to database
- Verify the DB pod is running (Rancher → Workloads → `scheduling-db`)
- The hostname in `DATABASE_URL` must match the DB's service name exactly (`scheduling-db`)
- Both workloads must be in the **same namespace**

### Can't log in
- Check the app pod logs for `[bootstrap]` lines — did it say it created the admin?
- If it says `no users exist, but ADMIN_EMAIL / ADMIN_PASSWORD env vars not set`, set them and restart the pod
- If a user exists but with wrong credentials, log in as super admin and reset their password in **Settings → Users** (or connect to the DB and run an `UPDATE user_profiles SET password_hash = ... WHERE email = ...`)

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
| `APP_URL` | optional | The address people open, e.g. `https://scheduling.yourcompany.com` — used in password-reset email links (read at run time since Sep 2026; unset, links point at `http://localhost:3000`) |

`ADMIN_*` vars only matter the first time the app starts with an empty `user_profiles` table. After the admin is created they're ignored and can be removed.

---

## Security Checklist

Before going live with real data:

- [ ] `JWT_SECRET` is a unique random string (not a dev default)
- [ ] `POSTGRES_PASSWORD` is strong
- [ ] `ADMIN_PASSWORD` was changed after first login (Settings → My account → Change password)
- [ ] DB is not exposed outside the cluster (only the app pod should reach it)
- [ ] Ingress uses HTTPS, and `APP_URL` is the `https://` address — see "For IT" §1
- [ ] Nightly backups run and have been restored once — "For IT" §2 and §3
- [ ] The database is on a durable disk and passed the persistence test — "For IT" §3

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
| All data lives in | the Postgres pod's disk: `scheduling-postgres` once moved ("For IT" §3), before that the hand-made `scheduling-db` |

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
- Auth is custom JWT (not OAuth / not SSO). Tokens live in HttpOnly cookies; a session lasts while it's used and ends after 8 hours idle (kiosk accounts: 30 days). The cookie is marked Secure when the browser came in over HTTPS — keep the ingress on HTTPS (and forwarding `X-Forwarded-Proto`), because over plain `http://` the sign-in, password included, crosses the network unencrypted.
- **No outbound network calls** except the database. (Optional SMTP for password-reset emails if you configure it.)

### Resource footprint

| Component | CPU | RAM | Disk |
|-----------|-----|-----|------|
| App pod | ~0.1 core idle, bursts to 0.5 during schedule generation | 256-512 MB | ephemeral |
| DB pod | ~0.05 core idle | 256-512 MB | 5-10 GB PVC typical |

Scales fine to ~100 concurrent users on a single app pod. Horizontal scaling works (stateless pods), though the DB stays single-instance.

### Persistence

- **All data** lives in Postgres. No files on disk.
- Back up Postgres and that's the full backup: `deploy/k8s/backup-cronjob.yaml`, set up as in "For IT" §2.
- App pods are stateless and can be killed/restarted without data loss.

### Network requirements

- Ingress traffic on port 80/443 to the app's port 3000
- Internal cluster traffic on port 5432 (app pod → db pod), same namespace
- **No outbound internet access required** (unless you enable SMTP for password resets)

### Security posture

- JWT secret is a runtime env var (`JWT_SECRET`, 32+ chars — generate with `openssl rand -base64 32`)
- Passwords are bcrypt-hashed in the DB
- All API routes go through `server/middleware/auth.ts`, which validates the JWT cookie and then reads the account (team, role, active) from the database, so deactivating someone or moving them to another team takes effect on their next click
- Multi-tenant isolation enforced in the API layer via the account's `team_id` from the database
- Non-root container user (uid 1001, defined in Dockerfile)
- Rate-limited at the API layer (default 200 req/min, stricter for auth endpoints)

### Updates

Build a new image → push to registry → Redeploy the `scheduling-app` workload. The bootstrap on startup picks up any new migrations automatically. **No manual SQL needed on updates.**
