/**
 * The role universe — ONE place, shared by the server (authorize.ts, the user
 * endpoints) and the client (Settings page, route middleware).
 *
 * Roles are stored as four boolean flags on user_profiles, for history's sake
 * (is_team_lead arrived in migration 021; the other three predate it). An
 * account holds exactly ONE role: the user endpoints write all four flags
 * together from `flagsForRole`, and anything reading an account derives its
 * role with `roleOf`, which takes the highest flag set — so a row that still
 * carries two flags from before Sep 2026 behaves as its stronger role until it
 * is next edited, at which point it is normalised.
 *
 * An account with no flag at all has NO role and can do nothing: every
 * team-scoped read and write is refused (see getTeamFilter / getWriteTeamId),
 * and the route middleware keeps it on the Settings page so a Super Admin can
 * assign one.
 */
export type Role = 'super_admin' | 'supervisor' | 'team_lead' | 'kiosk'

export interface RoleFlags {
  is_super_admin?: boolean | null
  is_admin?: boolean | null
  is_team_lead?: boolean | null
  is_display_user?: boolean | null
}

export const ROLES: { key: Role; label: string; description: string }[] = [
  {
    key: 'super_admin',
    label: 'Super Admin',
    description: 'Everything, including users and teams. System administrators only.',
  },
  {
    key: 'supervisor',
    label: 'Supervisor',
    description: 'Runs the team: schedules, approvals, review notes, request rules and blocked dates.',
  },
  {
    key: 'team_lead',
    label: 'Team Lead / Coordinator',
    description: 'Same as Supervisor, except request rules and blocked dates. Settings shows only their own account.',
  },
  {
    key: 'kiosk',
    label: 'Kiosk',
    description: 'The shared wall iPad: locked to the display board; can submit requests and look them up by UPI.',
  },
]

export const isRole = (v: unknown): v is Role => ROLES.some((r) => r.key === v)

/** Highest flag wins, so a legacy multi-flag row behaves as its stronger role. */
export function roleOf(u: RoleFlags | null | undefined): Role | null {
  if (!u) return null
  if (u.is_super_admin) return 'super_admin'
  if (u.is_admin) return 'supervisor'
  if (u.is_team_lead) return 'team_lead'
  if (u.is_display_user) return 'kiosk'
  return null
}

/** The four flags for a role — exactly one true. */
export function flagsForRole(role: Role): Required<{ [K in keyof RoleFlags]: boolean }> {
  return {
    is_super_admin: role === 'super_admin',
    is_admin: role === 'supervisor',
    is_team_lead: role === 'team_lead',
    is_display_user: role === 'kiosk',
  }
}

export const roleLabel = (role: Role | null): string =>
  ROLES.find((r) => r.key === role)?.label ?? 'No role'

/** Supervisor or above: request rules, blocked dates, the user list. */
export const canManageTeam = (u: RoleFlags | null | undefined): boolean => {
  const r = roleOf(u)
  return r === 'super_admin' || r === 'supervisor'
}

/** Team Lead or above: approvals, review notes, errors, attendance points. */
export const canLead = (u: RoleFlags | null | undefined): boolean => {
  const r = roleOf(u)
  return r === 'super_admin' || r === 'supervisor' || r === 'team_lead'
}
