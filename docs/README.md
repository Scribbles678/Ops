# Documentation Index

Documentation for the Operations Scheduling Tool (scheduling-app-v2).

## Available Documents

- **[CONTEXT.md](./CONTEXT.md)** — Full technical context: tech stack, directory structure, data model, auth, AI Schedule Builder algorithm, PTO Calendar
- **[ROLES.md](./ROLES.md)** — User roles, permissions matrix, team isolation rules
- **[RANCHER-DEPLOYMENT.md](./RANCHER-DEPLOYMENT.md)** — Production deployment on Rancher / Kubernetes

## Related Resources

- `../README.md` — Main project readme (features, quick start, env vars)
- `../sql-schema/` — PostgreSQL table definitions + triggers
- `../sql-schema/setup.sql` — Full schema bootstrap (run once)
- `../sql-schema/migrations/` — Incremental schema migrations

## Quick Orientation

**New to the project?** Start with [CONTEXT.md](./CONTEXT.md) — it covers architecture, data model, and the two focus areas (Automated Schedule Builder, PTO Calendar).

**Deploying?** See [RANCHER-DEPLOYMENT.md](./RANCHER-DEPLOYMENT.md).

**Setting up roles or teams?** See [ROLES.md](./ROLES.md).

## Abbott Labs Brand Colors

When customizing the UI or creating branded materials:

| Color Name   | Hex       | RGB            | Usage                    |
| ------------ | --------- | -------------- | ------------------------ |
| Royal Blue   | `#2E4AED` | 46, 74, 237    | Primary brand, buttons   |
| Portage      | `#96A3F5` | 150, 163, 245  | Secondary, accents       |
| Hawkes Blue  | `#D6DBFC` | 214, 219, 252  | Backgrounds, highlights  |
| Navy Blue    | `#000075` | 0, 0, 117      | Text, headers            |
| White        | `#FFFFFF` | 255, 255, 255  | Backgrounds              |

---

**Last Updated**: April 2026
