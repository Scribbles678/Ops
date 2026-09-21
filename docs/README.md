# Documentation Index

Documentation for the Operations Scheduling Tool (scheduling-app-v2).

**Each topic has exactly one home.** If something needs saying in two places, link
instead of restating — the schedule builder was once documented in three files and
all three drifted apart.

## Documents

| Doc | Covers | Changes |
|---|---|---|
| **[CONTEXT.md](./CONTEXT.md)** | Architecture, directory map, data model, auth & multi-tenancy, DB triggers, migrations ledger, env vars, deployment/bootstrap | slowly |
| **[SCHEDULE-BUILDER.md](./SCHEDULE-BUILDER.md)** | The builder engine: pipeline, cost function and weights, `staffing_priority`, the two block minimums, the review modal, how to validate a change | often |
| **[PTO-AND-REQUESTS.md](./PTO-AND-REQUESTS.md)** | PTO hours model, the shared modules, auto-approval rules and settings keys, `pto_days` storage conventions, PTO calendar, the kiosk UPI lookup, the change log, Employee Overview, attendance points, performance tracking | often |
| **[TESTING.md](./TESTING.md)** | How to verify a change: the four tiers, the engine harness (`sim-builder.mjs`), the browser smoke test (`ui-smoke.mjs`), multi-tenancy checks and fixtures | often |
| **[ROLES.md](./ROLES.md)** | The four roles and what each can do, the server gates, team isolation, how to roll the roles out to an existing install | rarely |
| **[RANCHER-DEPLOYMENT.md](./RANCHER-DEPLOYMENT.md)** | Production deployment on Rancher / Kubernetes, the release checklist (what to check before and after an update), plus an architecture reference for IT Q&A | rarely |
| **[DB-DATA-LOSS-INCIDENT.md](./DB-DATA-LOSS-INCIDENT.md)** | The Sep 2026 database loss: summary, what IT needs to check, how the Postgres image and the app bootstrap combine to turn an empty volume into a "fresh install", candidate causes, recovery options, timeline | during the incident |
| **[HARDENING-ROADMAP.md](./HARDENING-ROADMAP.md)** | Proposal (not yet implemented) for a durable deployment: StatefulSet + Retain storage, a bootstrap guard against silent re-init in production, backups, detection, versioned manifests, the persistence test | rarely |

## Where to start

- **New to the project?** [CONTEXT.md](./CONTEXT.md).
- **Working on the schedule builder?** [SCHEDULE-BUILDER.md](./SCHEDULE-BUILDER.md) — the two focus areas of this app are the builder and PTO.
- **Working on PTO, requests or availability?** [PTO-AND-REQUESTS.md](./PTO-AND-REQUESTS.md).
- **About to verify or ship a change?** [TESTING.md](./TESTING.md) — `npm run build` is only the first of four tiers.
- **Deploying?** [RANCHER-DEPLOYMENT.md](./RANCHER-DEPLOYMENT.md).
- **Helping with the Sep 2026 data loss?** [DB-DATA-LOSS-INCIDENT.md](./DB-DATA-LOSS-INCIDENT.md), then [HARDENING-ROADMAP.md](./HARDENING-ROADMAP.md).
- **Setting up roles or teams?** [ROLES.md](./ROLES.md).

## Related

- `../README.md` — project readme (features, quick start, env vars)
- `../CLAUDE.md` — working agreement for AI assistance in this repo
- `../sql-schema/setup.sql` — full schema bootstrap
- `../sql-schema/migrations/` — incremental migrations, auto-applied on boot

## Where the editors actually live

This repo used to carry unused twins of its live editors — `components/details/*Tab.vue`
beside `pages/details.vue`, `pages/admin/users.vue` beside `pages/settings.vue` — and
edits landed in the dead copy more than once. Both twins are gone now (Jul and Sep
2026). The rule survives them: **before editing a component, grep for where it is
mounted.** Today the live homes are:

| What | Where |
|---|---|
| Job Functions / Shifts / Target Hours editors | inline in `pages/details.vue` (Team Setup) |
| Employees & Training tab | `components/team/EmployeesTraining.vue` |
| User and team management | inline in `pages/settings.vue` |
| Employee Overview | `components/employee/Overview.vue`, rendered by `pages/employee-overview.vue` |
| Change log | `components/audit/ChangeLogModal.vue` |
| The schedule assignment modal | `components/schedule/ShiftGroupedSchedule.vue` (not `AssignmentModal.vue`) |

## Abbott Labs Brand Colors

| Color Name | Hex | RGB | Usage |
| ---------- | --- | --- | ----- |
| Royal Blue | `#2E4AED` | 46, 74, 237 | Primary brand, buttons |
| Portage | `#96A3F5` | 150, 163, 245 | Secondary, accents |
| Hawkes Blue | `#D6DBFC` | 214, 219, 252 | Backgrounds, highlights |
| Navy Blue | `#000075` | 0, 0, 117 | Text, headers |
| White | `#FFFFFF` | 255, 255, 255 | Backgrounds |

---

**Last Updated**: September 2026
