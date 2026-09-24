# Hardening Roadmap — Durable, Sustainable Deployment

**Status:** proposal. **Nothing here has been implemented.** This is the plan for
making the deployment survive routine cluster operations (node drains, upgrades,
pod rescheduling, workload redeploys) without data loss, and for making any
future data loss loud, bounded and recoverable.

Context for why this exists: `DB-DATA-LOSS-INCIDENT.md`.

---

## 1. Summary

The September 2026 data loss was not caused by a bug, a bad migration or an IT
mistake. It was caused by a deployment that was never hardened: the database's
storage was configured by hand, never versioned, never tested against a pod
move, and the application was designed to *hide* an empty database rather than
raise an alarm about one.

The fix is five layers. The first one prevents the incident; the other four
make sure that when something does go wrong, it is noticed in minutes, bounded
to at most one day of data, and recoverable by following a written procedure.

| # | Layer | One-line description | Prevents? | Detects? | Recovers? |
|---|---|---|---|---|---|
| 1 | **Durable storage** | Postgres as a StatefulSet on a real Azure Disk PVC with `Retain` | **yes** | | |
| 2 | **Refuse to silently rebuild** | App crashloops on an empty production DB unless explicitly allowed | | **yes** | |
| 3 | **Backups** | Nightly `pg_dump` to separate storage, with a tested restore | | | **yes** |
| 4 | **Detection** | Health endpoint reports when the DB was initialised and how many users it has | | **yes** | |
| 5 | **Runbook + tests** | Versioned manifests, a mandatory "kill the DB pod" persistence test, restore drill | yes | yes | yes |

**Guiding principles**

- **Everything about the deployment lives in the repository.** Manifests, storage
  class, backup job, env var contracts. If it was clicked in a UI, it does not
  exist as far as the next person is concerned.
- **Production must fail loudly.** A stateless app pod can be permissive. The
  thing that holds months of schedules cannot.
- **A backup that has never been restored is not a backup.**
- **Test the failure mode, not the happy path.** Deleting the DB pod on purpose
  is a five-minute test that would have caught this on day one.

---

## 2. Layer 1 — Durable storage (the actual fix)

### What changes

The database moves from a hand-configured Deployment to a **StatefulSet** with a
`volumeClaimTemplate`, on an Azure Disk storage class whose reclaim policy is
`Retain`. All of it is committed to the repo under `deploy/k8s/`.

Why each piece matters:

| Piece | Why |
|---|---|
| **StatefulSet, not Deployment** | The pod gets a stable identity (`scheduling-db-0`) and its PVC is bound to that identity. Deleting the pod, draining the node, or even deleting the StatefulSet leaves the PVC in place. A Deployment with a PVC can work, but a StatefulSet is the standard pattern and is what any Kubernetes admin expects to see for a database. |
| **`volumeClaimTemplate`** | The PVC is created *by* the StatefulSet from a template in the manifest. Nobody has to remember to create it, and nobody can accidentally pick "ephemeral" in a UI form. |
| **Azure Disk (`disk.csi.azure.com`) storage class** | Network-attached block storage that follows the pod to whichever node it lands on. This is what a node drain is supposed to be safe against. **Not** `local-path`, **not** `hostPath`, **not** `emptyDir`. |
| **`reclaimPolicy: Retain`** | AKS's default `managed-csi` class uses `Delete`: if the PVC is deleted, Azure deletes the disk. `Retain` means a deleted PVC leaves the disk (and the data) behind, recoverable by rebinding. This is the difference between "oops" and "gone". |
| **`allowVolumeExpansion: true`** | Growing the disk later is a one-line edit instead of a migration. |
| **Requests ≥ 10 Gi** | Azure Disk performance tiers scale with size; 5 Gi is the floor, not a target. |

### Sketch

```yaml
# deploy/k8s/storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi-retain
provisioner: disk.csi.azure.com
parameters:
  skuName: StandardSSD_LRS        # or Premium_LRS
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# deploy/k8s/db-statefulset.yaml (abridged)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: scheduling-db
  namespace: ns-operations-scheduler
spec:
  serviceName: scheduling-db
  replicas: 1
  selector: { matchLabels: { app: scheduling-db } }
  template:
    metadata: { labels: { app: scheduling-db } }
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine          # pin to a digest in the real manifest
          ports: [{ containerPort: 5432 }]
          env:
            - name: POSTGRES_DB
              value: scheduling
            - name: POSTGRES_USER
              valueFrom: { secretKeyRef: { name: scheduling-db, key: username } }
            - name: POSTGRES_PASSWORD
              valueFrom: { secretKeyRef: { name: scheduling-db, key: password } }
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata   # subdir: avoids the lost+found problem on Azure Disk
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
          resources:
            requests: { cpu: 100m, memory: 256Mi }
            limits:   { memory: 1Gi }
          readinessProbe:
            exec: { command: ["pg_isready", "-U", "postgres", "-d", "scheduling"] }
            periodSeconds: 5
  volumeClaimTemplates:
    - metadata: { name: data }
      spec:
        accessModes: [ReadWriteOnce]
        storageClassName: managed-csi-retain
        resources: { requests: { storage: 10Gi } }
```

Note the `PGDATA` subdirectory. A freshly formatted Azure Disk contains a
`lost+found` directory; the Postgres image refuses to `initdb` into a non-empty
directory. Pointing `PGDATA` one level down is the standard workaround.

### Migration path from the current deployment

This is a one-time cutover. It is also the natural moment to restore any data
recovered from the incident.

1. `pg_dump` the current database (even if it only contains rebuilt data).
2. Apply `storageclass.yaml`, the Secret, the headless Service and the
   StatefulSet. Wait for `scheduling-db-0` to be Running and Ready.
3. `pg_restore` / `psql` the dump into it.
4. Point the app's `DATABASE_URL` at the new service name (it can stay
   `scheduling-db` if the old Deployment and Service are removed first).
5. Run the persistence test (§6) **before** announcing it live.
6. Delete the old Deployment. Leave the old volume, whatever it is, for a week.

### Things that are deliberately *not* proposed

- **PodDisruptionBudget on the database.** A PDB with `minAvailable: 1` on a
  single-replica StatefulSet would block every node drain until someone
  intervenes. That protects against eviction but makes the app a permanent
  obstacle for the platform team. With durable storage, eviction is safe and a
  PDB is unnecessary. Reconsider only if drains cause unacceptable downtime.
- **High availability / replication.** One replica is fine for the load. HA
  Postgres (Patroni, CloudNativePG, Azure Database for PostgreSQL) is a
  separate conversation; durability comes first.
- **Moving to a managed database (Azure Database for PostgreSQL).** Worth
  raising with IT as an alternative to layers 1 and 3 together — Azure would own
  storage, backups and point-in-time restore. The app needs only a
  `DATABASE_URL` change and `DATABASE_SSL=true`. Not proposed here because it
  changes cost and ownership, which is a platform decision.

---

## 3. Layer 2 — Refuse to silently rebuild

### What changes

`server/plugins/bootstrap.ts` gets one guard. Today:

```
no schema → apply setup.sql → apply migrations → seed admin → serve traffic
```

Proposed:

```
no schema AND NODE_ENV=production AND BOOTSTRAP_ALLOW_INIT != "true"
  → log a loud, specific error
  → throw (pod crashloops; /api/health never goes green)

no schema AND (not production OR BOOTSTRAP_ALLOW_INIT=true)
  → existing behaviour

schema present
  → apply migrations as today (unchanged — updates stay zero-touch)
```

> **Correction (2026-09-23, verified).** When this was written, "throw" did **not**
> crashloop the pod: Nitro does not await the plugin, so a thrown error was only logged
> as `[unhandledRejection]` and the app kept serving a database with no tables — the
> `relation "pto_days" does not exist` IT saw. And `/api/health` was green on an empty
> database. Both are fixed: `bootstrap.ts` now catches any setup failure and, in a built
> app, calls `process.exit(1)`; `/api/health` is 503 until setup finishes. So a throw
> inside `runBootstrap()` now does crashloop the pod, as this layer assumes. One trap
> for implementing the guard: the build inlines `process.env.NODE_ENV` as
> `"production"`, so test for a built app with `!import.meta.dev`, not NODE_ENV
> (`BOOTSTRAP_ALLOW_INIT` is read at run time and is fine).

The error message should say exactly what happened and what to do:

```
[bootstrap] FATAL: no schema found in database "scheduling" at scheduling-db:5432.
[bootstrap] This is a production instance (NODE_ENV=production). Refusing to
[bootstrap] initialise an empty database because that usually means the volume
[bootstrap] was lost, not that this is a first deploy.
[bootstrap]   - If the data volume was lost: STOP. See docs/DB-DATA-LOSS-INCIDENT.md.
[bootstrap]   - If this really is a first deploy: set BOOTSTRAP_ALLOW_INIT=true,
[bootstrap]     redeploy, then remove the variable.
```

### Why this is the right trade-off

- First deploy still takes ten minutes: set one extra env var, remove it after.
- Routine updates are unaffected: migrations still apply automatically.
- The failure mode changes from "app comes up empty, users log in as
  `admin@example.com`, nobody knows anything is wrong until someone looks for
  last week's schedule" to "app is down, health check is red, the pod log says
  *the volume was lost* in the first ten lines." The second one gets IT's
  attention while the old node may still exist.
- The default-credential seed (`admin@example.com` / `admin123`) only runs on
  an empty `user_profiles`, so this guard also closes the window where a wiped
  production instance is briefly reachable with a well-known password.

### Related smaller changes

- The default admin credentials should not exist in production at all. Require
  `ADMIN_EMAIL` / `ADMIN_PASSWORD` when `NODE_ENV=production`; keep the defaults
  for local development.
- `RANCHER-DEPLOYMENT.md` step 3 gains `BOOTSTRAP_ALLOW_INIT=true` for first
  deploy, with an explicit "remove after first boot" note.

---

## 4. Layer 3 — Backups

### What changes

A Kubernetes **CronJob** in the same namespace runs `pg_dump` nightly, writes a
compressed custom-format dump to a **separate** PVC (Azure Files, so it is
readable from anywhere and survives the database volume), and prunes dumps
older than 30 days. Weekly, a copy goes to Azure Blob Storage if IT can provide
a storage account — that is the off-cluster copy.

| Property | Value | Why |
|---|---|---|
| Schedule | `0 2 * * *` (02:00 daily) | Off-shift; the app is used during the day |
| Format | `pg_dump -Fc` (custom, compressed) | Restorable table-by-table with `pg_restore`; ~10× smaller than plain SQL |
| Target | PVC `scheduling-db-backups` on Azure Files, 20 Gi | Separate from the DB disk; RWX so a restore pod can read it while the DB pod is up |
| Retention | 30 daily, 12 weekly | Bounded storage; covers "we noticed a week later" |
| Off-cluster | Weekly copy to Azure Blob (optional, needs IT) | Survives cluster deletion |
| Credentials | Same Secret as the DB | No new secrets to manage |
| Verification | Job fails (and the CronJob shows it) if `pg_dump` exits non-zero or the file is < 10 KB | A zero-byte "backup" is worse than none |

### Sketch

```yaml
# deploy/k8s/backup-cronjob.yaml (abridged)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scheduling-db-backup
  namespace: ns-operations-scheduler
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 7
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: pg-dump
              image: postgres:16-alpine
              env:
                - name: PGPASSWORD
                  valueFrom: { secretKeyRef: { name: scheduling-db, key: password } }
              command: ["/bin/sh", "-c"]
              args:
                - |
                  set -eu
                  f=/backups/scheduling-$(date +%F).dump
                  pg_dump -h scheduling-db -U postgres -d scheduling -Fc -f "$f"
                  test "$(stat -c %s "$f")" -gt 10240
                  find /backups -name 'scheduling-*.dump' -mtime +30 -delete
                  ls -lh /backups | tail -5
              volumeMounts:
                - { name: backups, mountPath: /backups }
          volumes:
            - name: backups
              persistentVolumeClaim: { claimName: scheduling-db-backups }
```

### Restore procedure (must be written *and rehearsed*)

Outline, to be expanded into a step-by-step runbook in `RANCHER-DEPLOYMENT.md`:

1. Scale the app to 0 replicas (stops writes).
2. Start a one-off pod with `postgres:16-alpine`, the backups PVC mounted,
   and the DB secret.
3. `pg_restore --clean --if-exists -h scheduling-db -U postgres -d scheduling /backups/<file>.dump`
4. Scale the app back to 1. Confirm data in the UI.

Rehearse it once against a scratch database in the same cluster before it is
ever needed. Record how long it took.

---

## 5. Layer 4 — Detection

### What changes

Two small application changes so that "the database was rebuilt" is visible
without reading pod logs:

1. **A `_meta` table**, created by bootstrap the first time it initialises a
   schema, holding `initialized_at` (timestamp) and `initialized_by` (app
   version / image tag). Migrations never touch it.
2. **`/api/health` reports it**, alongside a user count:

   ```json
   {
     "status": "ok",
     "database": "connected",
     "initialized_at": "2026-04-12T14:03:11Z",
     "users": 47,
     "timestamp": "2026-09-20T18:00:00Z"
   }
   ```

Anyone — a person in a browser, an uptime monitor, a Copilot prompt — can then
see at a glance that a database that was initialised in April is reporting an
`initialized_at` of last Friday. If IT has a monitoring stack (Azure Monitor,
Prometheus, Uptime Kuma), alert on `initialized_at` changing or `users`
dropping to 1.

This layer is cheap (an hour of work), purely additive, and is what makes
layer 2's crashloop unnecessary to *discover* — but layer 2 is still what makes
it *impossible to miss*.

---

## 6. Layer 5 — Runbook, manifests in the repo, and tests

### Manifests in the repo

New directory `deploy/k8s/` containing everything the namespace needs:

```
deploy/k8s/
  namespace.yaml
  storageclass.yaml           # managed-csi-retain
  db-secret.example.yaml      # template; real secret created by IT, never committed
  db-service.yaml             # headless service "scheduling-db"
  db-statefulset.yaml
  db-backups-pvc.yaml         # Azure Files, RWX
  backup-cronjob.yaml
  app-deployment.yaml         # env from a Secret + ConfigMap; image tag templated
  app-service.yaml
  ingress.yaml
  kustomization.yaml          # so `kubectl apply -k deploy/k8s` does the whole thing
```

Rancher can apply raw YAML (Cluster → Import YAML) or the pipeline can run
`kubectl apply -k`. Either way the source of truth is git, reviewable in a PR,
and the next person who deploys this app cannot pick "ephemeral volume" by
accident because there is no form.

### The persistence test — mandatory after any deploy that touches the DB

```bash
# 1. note something specific in the UI (e.g. the number of employees on a team)
# 2. kill the database pod on purpose
kubectl delete pod -n ns-operations-scheduler scheduling-db-0
# 3. wait for it to come back
kubectl rollout status statefulset/scheduling-db -n ns-operations-scheduler
# 4. confirm the DB pod log says "Skipping initialization", NOT "init process complete"
kubectl logs -n ns-operations-scheduler scheduling-db-0 | head -20
# 5. confirm the app pod log says "base schema already present"
# 6. confirm the number from step 1 is still there
```

If IT is willing, the stronger version is `kubectl drain <node>` on the node the
DB pod is on — that is the exact event that caused the incident.

### Restore drill — once, then annually

Run the §4 restore procedure against a scratch database. Fix whatever is wrong
with the runbook. Note the elapsed time in the runbook.

### Documentation updates

- `RANCHER-DEPLOYMENT.md` — rewrite steps 2 and 3 around `deploy/k8s/`, add
  `BOOTSTRAP_ALLOW_INIT`, add the persistence test as a numbered step, add the
  restore runbook, move "PVC snapshots or a pg_dump CronJob" from the security
  checklist (where it was ignored) into the deploy steps (where it is required).
- `CONTEXT.md` § "Deployment & Bootstrap" — document the guard and `_meta`.
- Both documents get a "Last verified against the cluster on <date>" line.

---

## 7. Prioritised plan

| Priority | Item | Effort | Owner | Depends on |
|---|---|---|---|---|
| **P0** | Confirm root cause and attempt recovery (`DB-DATA-LOSS-INCIDENT.md` §2, §6) | hours | IT + app owner | — |
| **P1** | Layer 1: StorageClass + StatefulSet + cutover (§2) | half a day to write, an hour to apply | app owner writes, IT applies | P0 (so recovered data can be restored into it) |
| **P1** | Persistence test on the new StatefulSet (§6) | 15 min | IT + app owner | Layer 1 |
| **P1** | Layer 2: bootstrap guard (§3) | 1–2 hours + a new image | app owner | none; ship with the next image |
| **P2** | Layer 3: backup CronJob + backups PVC (§4) | half a day | app owner writes, IT applies | Layer 1 |
| **P2** | Restore drill (§4, §6) | 1 hour | app owner | Layer 3 |
| **P2** | Layer 4: `_meta` + health endpoint (§5) | 1–2 hours | app owner | none |
| **P3** | Full `deploy/k8s/` including app, service, ingress; retire hand-configured workloads (§6) | 1 day | app owner + IT | Layers 1, 3 |
| **P3** | Off-cluster backup copy to Azure Blob (§4) | depends on IT | IT | Layer 3 |
| **P3** | Docs rewrite (§6) | 2 hours | app owner | everything above |
| **later** | Evaluate Azure Database for PostgreSQL as a replacement for layers 1 + 3 | discussion | IT + app owner | — |

Everything in P1 can be ready to apply within a day. Nothing should be applied
until P0 is resolved — recovering data comes before rebuilding the platform
under it.

---

## 8. What this does not cover

Out of scope for durability, noted so they are not forgotten:

- **Secrets management.** `JWT_SECRET` and the DB password are plain env vars
  on the workloads today. They should be Kubernetes Secrets (the sketches above
  assume that), ideally sourced from Azure Key Vault via the CSI driver.
- **Image tagging.** `ui_v11` is a mutable tag. Pinning by digest, or at least
  never re-pushing a tag, makes rollbacks meaningful.
- **Resource limits** on the app pod (currently unset in the hand-configured
  workload, per `RANCHER-DEPLOYMENT.md` guidance of 256–512 MB).
- **The CI/CD pipeline** (git → GitHub org → ARC runner → Rancher). Once
  `deploy/k8s/` exists, the pipeline should apply it; today it only pushes an
  image.
- **Application-level audit of destructive operations.** The app already has an
  `audit_log` table for business changes; that is unrelated to this incident
  and adequate.
