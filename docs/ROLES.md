# Roles & Permissions

Four roles. An account holds **exactly one**, and an account with **no role can do
nothing**. The role universe lives in one file, `utils/roles.ts`, used by the server
gates and the Settings page alike — if you change a role's meaning, change it there.

---

## The four roles

| Role | Stored as | Who | Can |
|---|---|---|---|
| **Super Admin** | `is_super_admin` | system owner / IT | everything, plus users and teams (create, edit, reset passwords, change any team assignment, switch their own team) |
| **Supervisor** | `is_admin` | runs the team | everything on the floor **plus** Request Rules, blocked dates, and the **change log** (who approved / rejected / deleted what — see PTO-AND-REQUESTS.md). *(Labelled "Admin" until Sep 2026 — same flag, same rights.)* |
| **Team Lead / Coordinator** | `is_team_lead` | day-to-day leads | schedules, employees, training, shifts, targets, PTO entries; approve / reject / delete requests; errors, performance notes and attendance points; the full Employee Overview. On Settings they see only **Change Password** and **Account Information**. |
| **Kiosk** | `is_display_user` | the shared wall iPad | locked to `/display`; can submit requests and look one employee's requests up by UPI |

**No role** (all four flags false): can sign in, change their password and see their
Account Information — nothing else. Every team-scoped read and write is refused
(403) and the route middleware keeps them on `/settings`, which explains why. A
Super Admin assigns a role from User Management.

There is no "regular user" any more. The old no-flag account could build schedules
and edit the team setup; that role was folded into Team Lead / Coordinator when the
roles were tightened in Sep 2026.

---

## How it is enforced

**Server** — `server/utils/authorize.ts`:

| gate | who passes | used by |
|---|---|---|
| `requireAuth` | any active account | most reads and writes (then team-scoped) |
| `requireTeamLead` | Team Lead, Supervisor, Super Admin | request approve/reject/delete, performance errors and notes, attendance points |
| `requireSupervisor` | Supervisor, Super Admin | team settings (request rules), blocked dates, the user list, the change log |
| `requireSuperAdmin` | Super Admin | create/edit/delete users, reset passwords, teams |

`getTeamFilter` / `getWriteTeamId` additionally refuse a **no-role** account and a
**team-less** account, so those never reach a query. The Employee Overview API
returns its review sections (`performance`, `attendancePoints`) only to Team Lead
and above.

**Client** — `middleware/auth.global.ts` sends Kiosk accounts to `/display` and
no-role accounts to `/settings`; the Settings page shows the Request Rules card
only to Supervisors and Super Admins, and User / Team Management only to Super
Admins. Client checks are convenience; the server gates are the authority.

**Exactly one role.** `POST /api/admin/users/create` requires a `role` and
`PUT /api/admin/users/[id]` takes one; both write all four flags together from
`flagsForRole()`. The Settings forms offer a single Role dropdown. Reads derive the
role with `roleOf()` — the **highest flag wins** — so an account that still carries
two flags from before Sep 2026 behaves as its stronger role until it is next edited,
at which point it is normalised. No migration rewrote anyone's flags.

A role change, a team move or a deactivation applies on the person's **next
click**: the API reads the account from the database on every call
(`server/middleware/auth.ts`). Until Sep 2026 the role travelled in the signed
token, so a change waited for the next sign-in — up to 8 hours, and never for a
kiosk, whose session renewed itself.

---

## Team isolation

Unchanged by roles: every account belongs to one team, `getTeamFilter()` returns the
caller's own team for everyone (Super Admins included — they switch team in
Settings → Change Team), and only User Management reads across teams via the
explicit `readsAllTeams()`. See `CONTEXT.md` → Multi-Tenancy.

---

## Rolling the roles out to an existing install

The migration (021) only adds the `is_team_lead` column. On deploy:

1. Nobody's flags change, so nobody is locked out: Super Admins stay Super Admins,
   the kiosk stays the kiosk, and **every Admin is now a Supervisor** with the rights
   they already had.
2. The people who should be **Team Lead / Coordinator** (today's Admins who are
   really leads) need reassigning by hand in Settings → User Management: open the
   person, pick the role, save. Their password and team are untouched; it takes
   effect immediately. What they lose is the Request Rules card.
3. **Check for accounts with no flags before deploying** — after this change they
   cannot do anything until given a role:

   ```sql
   SELECT email, team_id FROM user_profiles
   WHERE NOT is_super_admin AND NOT is_admin AND NOT is_team_lead AND NOT is_display_user
     AND is_active;
   ```

   Assign each a role (probably Team Lead / Coordinator) in User Management right
   after deploying, or beforehand via SQL:
   `UPDATE user_profiles SET is_team_lead = true WHERE email = '…';`

---

## Assigning a role

Settings → User Management (Super Admin only) → Create User, or Edit on an existing
row → **Role** dropdown → Save. Every account needs a team as well; the form
requires both.

Via SQL, set exactly one flag true and the other three false.

---

## Test fixtures (dev database)

| Login | Role | Team |
|---|---|---|
| `admin@example.com` / `admin123` | Super Admin | Default Team |
| `siteb.admin@example.com` / `testpass123` | Supervisor | Site B |
| `lead@example.com` / `testpass123` | Team Lead / Coordinator | Default Team |
| `kiosk@example.com` / `testpass123` | Kiosk | Default Team |
| `tenant.test@example.com` / `testpass123` | **no role** — for testing the lock-out | Default Team |

---

**Last Updated**: September 2026
