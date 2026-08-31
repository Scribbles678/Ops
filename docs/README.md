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
| **[PTO-AND-REQUESTS.md](./PTO-AND-REQUESTS.md)** | PTO hours model, the shared modules, auto-approval rules and settings keys, `pto_days` storage conventions, PTO calendar, Employee Overview, performance tracking | often |
| **[TESTING.md](./TESTING.md)** | How to verify a change: the four tiers, the engine harness (`sim-builder.mjs`), the browser smoke test (`ui-smoke.mjs`), multi-tenancy checks and fixtures | often |
| **[ROLES.md](./ROLES.md)** | Roles, permissions matrix, team isolation rules, troubleshooting | rarely |
| **[RANCHER-DEPLOYMENT.md](./RANCHER-DEPLOYMENT.md)** | Production deployment on Rancher / Kubernetes, plus an architecture reference for IT Q&A | rarely |

## Where to start

- **New to the project?** [CONTEXT.md](./CONTEXT.md).
- **Working on the schedule builder?** [SCHEDULE-BUILDER.md](./SCHEDULE-BUILDER.md) — the two focus areas of this app are the builder and PTO.
- **Working on PTO, requests or availability?** [PTO-AND-REQUESTS.md](./PTO-AND-REQUESTS.md).
- **About to verify or ship a change?** [TESTING.md](./TESTING.md) — `npm run build` is only the first of four tiers.
- **Deploying?** [RANCHER-DEPLOYMENT.md](./RANCHER-DEPLOYMENT.md).
- **Setting up roles or teams?** [ROLES.md](./ROLES.md).

## Related

- `../README.md` — project readme (features, quick start, env vars)
- `../CLAUDE.md` — working agreement for AI assistance in this repo
- `../sql-schema/setup.sql` — full schema bootstrap
- `../sql-schema/migrations/` — incremental migrations, auto-applied on boot

## Two live twins to know about

Legacy duplicates that are **not** wired up. Edit the live one:

| Live | Dead twin |
|---|---|
| `pages/details.vue` (monolithic, editors inline) | `components/details/*Tab.vue` |
| `pages/settings.vue` (Super Admin Management section) | `pages/admin/users.vue` — deleted Jul 2026 |

## Abbott Labs Brand Colors

| Color Name | Hex | RGB | Usage |
| ---------- | --- | --- | ----- |
| Royal Blue | `#2E4AED` | 46, 74, 237 | Primary brand, buttons |
| Portage | `#96A3F5` | 150, 163, 245 | Secondary, accents |
| Hawkes Blue | `#D6DBFC` | 214, 219, 252 | Backgrounds, highlights |
| Navy Blue | `#000075` | 0, 0, 117 | Text, headers |
| White | `#FFFFFF` | 255, 255, 255 | Backgrounds |

---

**Last Updated**: August 2026
