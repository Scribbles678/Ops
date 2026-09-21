# Database Data Loss — Incident Context (September 2026)

**Status:** open — root cause not yet confirmed, data recovery not yet attempted.
**Purpose of this document:** shared context for anyone helping diagnose or recover.
It starts with a plain-language summary and gets progressively more technical.
Nothing in the application has been changed in response to this incident yet.

---

## 1. Summary (one-minute read)

The Operations Scheduling app (namespace `ns-operations-scheduler`) ran in the
cluster for several months without issue. On **Friday 18 Sep 2026**, a
cluster-wide secret update on the IT side drained every node one by one. As part
of that drain, both pods in the namespace — the app pod and the PostgreSQL
database pod — were evicted and recreated. When the app came back up, **the
database was empty**: all teams, employees, schedules, PTO and user accounts
were gone, and the app presented itself as a brand-new installation with the
default `admin@example.com` login.

Three facts explain how a routine node drain can produce this:

1. **PostgreSQL only keeps data that is on a persistent volume.** If the volume
   under `/var/lib/postgresql/data` is ephemeral, or lives on one specific
   node's disk, then a pod that comes back on a different node starts with an
   empty directory.
2. **The official `postgres:16-alpine` image initialises a brand-new empty
   database whenever it starts with an empty data directory.** This is normal,
   documented behaviour of that image.
3. **The app is self-bootstrapping.** On every start it checks whether the
   schema exists; if not, it creates the schema, applies all migrations and
   creates a default admin account. So an empty database becomes a working,
   empty app within seconds — with no error and no alarm.

**Nothing in the application deletes data.** The app cannot drop or truncate its
own tables. The only way to reach the observed state is for PostgreSQL to have
started with an empty data directory. The open question is *why* the data
directory was empty, and that is a storage question, not an application one.

**The most likely explanation** is that the database workload was created by hand
in the Rancher UI months ago with a volume that was not actually persistent
across nodes (an ephemeral `emptyDir`, or a `hostPath` bind-mount to one node's
disk). Friday was simply the first time the pod ever moved.

---

## 2. What we need from IT — checks, in priority order

These are read-only checks. Please do not delete, redeploy or "clean up" any
node, pod or volume until check 1 and check 3 are done — if the data is on a
drained node's disk it may still be recoverable.

### Check 1 — What kind of volume is the database using? (most important)

```bash
kubectl get pvc -n ns-operations-scheduler
kubectl describe pod -n ns-operations-scheduler -l app=scheduling-db
```

In the `describe pod` output, find the **Volumes:** section and the entry
mounted at `/var/lib/postgresql/data`. It will be one of:

| Type shown | Meaning | Data after a node drain |
|---|---|---|
| `PersistentVolumeClaim` | A real Kubernetes PVC (Azure Disk / Azure Files) | **Should survive.** If we see this, something else is wrong — go to check 4. |
| `EmptyDir` | Ephemeral, lives and dies with the pod | **Gone** the moment the pod was evicted. |
| `HostPath` | A directory on the node the pod was running on | Data is **still on the old node's disk** unless that node was reimaged or deleted. |
| Nothing mounted there | Data was in the container's writable layer | Gone with the old container. |

If `kubectl get pvc` returns nothing, the volume was never persistent.

### Check 2 — Did PostgreSQL initialise from empty on Friday? (definitive)

```bash
kubectl logs -n ns-operations-scheduler <scheduling-db-pod-name> | head -60
```

Look for one of these two lines near the top:

- `PostgreSQL init process complete; ready for start up.` → the data directory
  **was empty** when this pod started. Confirms the mechanism above.
- `PostgreSQL Database directory appears to contain a database; Skipping initialization` →
  the data directory **was not empty**. The problem is somewhere else (see §5).

The app pod's log confirms the same thing from the other side:

```bash
kubectl logs -n ns-operations-scheduler <app-pod-name> | grep bootstrap
```

`[bootstrap] no schema detected — applying setup.sql` followed by
`[bootstrap]   ✓ first super admin created: admin@example.com` timestamps the
exact moment the fresh install was created.

### Check 3 — Which node was the database pod on *before* Friday?

The new pods are on `aks-default-10746939-vmss00002m`. We need to know which
node the old `scheduling-db` pod was on before the drain. Sources:

- Azure Monitor / Log Analytics container logs or `KubePodInventory` for the
  namespace, if the cluster ships them.
- Whoever ran the secret update — the drain order, and whether any nodes were
  **reimaged, scaled down or replaced** rather than just drained and uncordoned.

If the volume is `HostPath` and the old node still exists, the data directory is
almost certainly still on it. That is the recovery path (§6).

### Check 4 — Only if check 1 shows a real PVC

```bash
kubectl get pv
kubectl get pvc -n ns-operations-scheduler -o yaml
kubectl get events -n ns-operations-scheduler --sort-by=.lastTimestamp | tail -50
```

Things to look for:

- A PersistentVolume in `Released` state with an older creation timestamp — a
  previous PV whose claim was deleted. If its `persistentVolumeReclaimPolicy` is
  `Retain`, the disk and the data are still there.
- The PVC's own `creationTimestamp`. If it is newer than the app deployment
  (months old), the PVC was recreated at some point.
- `FailedAttachVolume` / `FailedMount` / `Multi-Attach error` events from
  Friday. These can indicate an Azure Disk that could not follow the pod.
- The app's `DATABASE_URL` env var on the app workload. Confirm it still points
  at `scheduling-db:5432/scheduling` and not a different host or database name.

### Check 5 — Is there any backup anywhere?

- Azure Backup for AKS, or Azure Disk snapshots, on this cluster or its disks.
- Velero or any other cluster backup tooling.
- Any `pg_dump` anyone ever took. (The application repo does not ship a backup
  job; one was listed as a pre-go-live checklist item but there is no evidence
  it was created.)

---

## 3. How the app is deployed (what IT needs to know)

Two containers, one namespace, nothing else:

| Workload | Image | Role |
|---|---|---|
| `app` | `acrbtscaasdev.azurecr.io/acrbtscaasdev/operations-scheduler:ui_v11` | Web UI + API server (Node.js / Nuxt). **Stateless.** Safe to kill, restart, scale. |
| `scheduling-db` | `postgres:16-alpine` (official Docker Hub image) | The database. **All data lives here**, in `/var/lib/postgresql/data`. |

- Both workloads are plain Kubernetes **Deployments** (pod names carry a
  ReplicaSet hash, e.g. `scheduling-db-7d49979887-…`). The database is *not* a
  StatefulSet.
- They talk over the cluster network on port 5432. The app finds the database
  via the env var `DATABASE_URL=postgresql://postgres:<pw>@scheduling-db:5432/scheduling`.
- The cluster is **AKS** (node names `aks-default-…-vmss…`), managed through
  Rancher. Rancher is the UI; Azure provides the nodes and storage.
- **The application repository contains no Kubernetes manifests.** The workloads,
  services, ingress and the database volume were configured by hand in the
  Rancher UI following `RANCHER-DEPLOYMENT.md`, which specifies "PVC ≥ 5 GB
  mounted at `/var/lib/postgresql/data`" but has no way to enforce or verify it.
- The app's health endpoint is `GET /api/health`; it returns 200 if it can run
  `SELECT 1` against the database. It does **not** distinguish a healthy
  database from an empty one.

### What "pod restarted, not deployment" actually means

Both pods currently show `Restarts: 0` and have new pod names. That means they
were not restarted in place — the old pods were **evicted** by the node drain
and the Deployment controller created **new** pods, potentially on a different
node. From the Deployment's point of view nothing changed. From the pod's point
of view it is a brand-new container starting from scratch. Whether the data
survives that depends entirely on the volume type (§2, check 1).

---

## 4. The mechanism in detail

### 4.1 PostgreSQL image behaviour

The `postgres:16-alpine` entrypoint (`docker-entrypoint.sh`) does this on every
start:

1. Look for `$PGDATA/PG_VERSION` (default `PGDATA=/var/lib/postgresql/data`).
2. If it exists → log `Database directory appears to contain a database;
   Skipping initialization` and start the server. `POSTGRES_USER`,
   `POSTGRES_PASSWORD` and `POSTGRES_DB` are **ignored** in this case.
3. If it does not exist → run `initdb`, create the superuser from
   `POSTGRES_USER` / `POSTGRES_PASSWORD`, create the database named by
   `POSTGRES_DB`, log `init process complete`, and start the server.

Consequences:

- A changed `POSTGRES_PASSWORD` **cannot** wipe an existing database. It would
  simply be ignored, and the app would fail to authenticate if its
  `DATABASE_URL` used the new password. That is not what was observed.
- An empty data directory **always** produces a fresh, empty `scheduling`
  database with the configured password. That *is* what was observed.

### 4.2 Application bootstrap behaviour

`server/plugins/bootstrap.ts` runs on every app start. In order:

1. Take a PostgreSQL advisory lock (so two app replicas cannot race).
2. Check whether the `user_profiles` table exists.
   - **No** → execute `sql-schema/setup.sql` (creates every table, trigger and
     function). Log: `[bootstrap] no schema detected — applying setup.sql`.
   - **Yes** → log `[bootstrap] base schema already present`.
3. Execute every file in `sql-schema/migrations/*.sql` in filename order. All
   are idempotent (`IF NOT EXISTS` / `ON CONFLICT DO NOTHING`); they add
   tables and columns and never delete data.
4. If `user_profiles` has zero rows → create a super-admin from the env vars
   `ADMIN_EMAIL` / `ADMIN_PASSWORD`, falling back to `admin@example.com` /
   `admin123`. Log: `[bootstrap]   ✓ first super admin created: …`.
5. Release the lock.

This design makes the *first* deploy painless — no manual SQL, no seed scripts.
The trade-off, which this incident exposed, is that it makes an accidentally
empty database in production indistinguishable from an intentional fresh
install. The app does not know how old it is supposed to be.

### 4.3 What the app does *not* do

A search of the schema and migrations for destructive statements finds:

- Migration `014-remove-database-cleanup.sql` drops two long-unused
  bookkeeping tables (`cleanup_log`, `cleanup_status`) — not data tables, and
  this migration has been applied for months.
- One `DELETE FROM employee_training` inside a stored function, scoped to a
  single employee's training rows when their training list is edited.

There is no `DROP TABLE`, `TRUNCATE` or bulk `DELETE` against any data table
anywhere in the codebase. The application has no code path that can produce an
empty database from a populated one.

---

## 5. Candidate root causes, ranked

| # | Cause | Fits the evidence? | How to confirm |
|---|---|---|---|
| 1 | DB volume is `emptyDir` (ephemeral). Pod eviction deleted it. | **Best fit.** Worked for months because the pod never moved; died on the first drain. | Check 1 shows `EmptyDir`. |
| 2 | DB volume is `hostPath`. Pod came back on a different node with an empty directory. | **Strong fit.** Same failure profile as #1; difference is the data may still exist on the old node. | Check 1 shows `HostPath`; check 3 identifies the old node. |
| 3 | Real PVC exists but is backed by a node-local storage class, and the old node was reimaged during the secret update. | Plausible if the update replaced nodes rather than draining them. | Check 1 shows a PVC; `kubectl get pv` shows a local / node-affinity storage class; IT confirms node replacement. |
| 4 | Real Azure Disk PVC, but the workload or PVC was deleted and recreated at some point, and the old PV was released. | Possible. Would show as a PVC younger than the deployment, and possibly an old `Released` PV. | Check 4. If the old PV has `Retain`, the data is recoverable. |
| 5 | `DATABASE_URL` now points at a different (empty) Postgres. | Unlikely — project-level config reportedly unchanged. | Check 4, last bullet. |
| 6 | Someone or something ran destructive SQL. | No evidence; the app has no such code path. | Would require DB audit logs, which are not enabled. |

---

## 6. Recovery options

**Do the checks in §2 before any of this.**

### If `hostPath` (cause 2) and the old node still exists

The data directory is on that node's filesystem at the configured host path.
Retrieval outline:

```bash
# open a privileged debug shell on the old node
kubectl debug node/<old-node-name> -it --image=busybox -- sh
# the node filesystem is under /host
ls /host/<configured-host-path>
tar czf /host/tmp/pgdata.tgz -C /host/<configured-host-path> .
```

Copy the archive out, then restore it into the new persistent volume (this is a
file-level copy of a PostgreSQL 16 data directory; the server must be stopped
while it is copied in, and the copy must be from the same major version — it
is). Alternatively, start a throwaway `postgres:16-alpine` pod with that
directory mounted, `pg_dump` from it, and restore the dump — cleaner and safer.

### If a released PV exists (cause 4) with `Retain`

Create a new PVC that binds to the old PV (by setting `volumeName` and clearing
the PV's `claimRef`), point the database workload at it, restart. Standard
Kubernetes procedure; the disk was never erased.

### If `emptyDir`, or the old node is gone

The data inside the cluster is unrecoverable. Remaining sources:

- Azure Backup for AKS / disk snapshots (check 5).
- Any exports the app produced: the schedule page has a CSV export, and users
  may have downloaded schedules or PTO reports. These can seed a rebuild but
  are not a database restore.
- Rebuild by hand: teams, employees, job functions, training, shifts, user
  accounts. The app's bootstrap will already have created the schema and a
  default admin, so this is data entry, not a reinstall.

### After recovery (or rebuild)

The current database is the new "live" one. Do not put it back on the same
kind of volume that lost the data. See `HARDENING-ROADMAP.md` for what to
change before trusting it with real data again.

---

## 7. Timeline (to be completed as facts come in)

| When | What | Source |
|---|---|---|
| ~Mar–Apr 2026 | App and database workloads created in Rancher in `ns-operations-scheduler` | deployment history |
| Apr–Sep 2026 | App in daily production use; DB pod never evicted | — |
| Fri 18 Sep 2026 | Cluster secret update; nodes drained one by one; app and db pods evicted and recreated | IT |
| Fri 18 Sep 2026 ~15:30 | App observed to be empty, default admin login active | app owner |
| Fri 18 Sep 2026 | Platform team confirms pods were recreated by the drain (deployments unchanged) and reports the volume as still attached | platform team |
| — | Volume type confirmed (check 1) | *pending* |
| — | DB pod logs checked for initdb (check 2) | *pending* |
| — | Previous node identified (check 3) | *pending* |

---

## 8. Reference

### Files in the application repository

| Path | What it is |
|---|---|
| `server/plugins/bootstrap.ts` | The self-bootstrap described in §4.2 |
| `server/utils/db.ts` | The `pg` connection pool (reads `DATABASE_URL`, `DATABASE_SSL`) |
| `server/api/health.ts` | `/api/health` — `SELECT 1` only |
| `sql-schema/setup.sql` | Full base schema (~700 lines), applied when no schema exists |
| `sql-schema/migrations/*.sql` | 21 idempotent migrations, applied on every boot |
| `Dockerfile` | Builds the app image; copies `sql-schema/` in so bootstrap can find it |
| `docker-compose.yml` | Local development only — defines a named volume `postgres_data`. **Not** used in the cluster. |
| `docs/RANCHER-DEPLOYMENT.md` | The guide the cluster deployment was built from |
| `docs/CONTEXT.md` § "Deployment & Bootstrap" | Architecture reference |

### Environment variables on the app workload

| Var | Purpose |
|---|---|
| `DATABASE_URL` | `postgresql://postgres:<pw>@scheduling-db:5432/scheduling` |
| `DATABASE_SSL` | `false` for in-cluster Postgres |
| `JWT_SECRET` | Signs login cookies. Unchanged; unrelated to data. |
| `NODE_ENV` | `production` |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_NAME` | Only read when `user_profiles` is empty |

### Environment variables on the database workload

| Var | Purpose |
|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | Only read by the image during `initdb` (empty data dir). Ignored otherwise. |
| `PGDATA` | Not set; image default `/var/lib/postgresql/data` applies. |

### Log lines that matter

| Where | Line | Means |
|---|---|---|
| db pod | `PostgreSQL init process complete; ready for start up.` | Started from an empty data directory |
| db pod | `Database directory appears to contain a database; Skipping initialization` | Existing data found |
| app pod | `[bootstrap] no schema detected — applying setup.sql` | App found an empty database and built a fresh schema |
| app pod | `[bootstrap] base schema already present` | App found existing data |
| app pod | `[bootstrap]   ✓ first super admin created: …` | Default admin created — only happens on an empty `user_profiles` |
| app pod | `[bootstrap] FAILED: password authentication failed` | Would indicate a credential mismatch — **not** what happened |

### Related

- `HARDENING-ROADMAP.md` — what to change so this cannot recur.
- `RANCHER-DEPLOYMENT.md` — current deployment guide (to be revised).
