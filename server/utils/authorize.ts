import type { H3Event } from 'h3'

export interface AuthUser {
  id: string
  email: string
  username: string
  full_name: string | null
  team_id: string | null
  is_admin: boolean
  is_super_admin: boolean
  is_display_user: boolean
  is_active: boolean
  employee_id: string | null
}

/**
 * Get the authenticated user from the request context.
 * Returns null if not authenticated (does not throw).
 */
export function getAuthUser(event: H3Event): AuthUser | null {
  return event.context.user ?? null
}

/**
 * Require authentication. Throws 401 if not logged in.
 */
export function requireAuth(event: H3Event): AuthUser {
  const user = getAuthUser(event)
  if (!user) {
    throw createError({ statusCode: 401, message: 'Authentication required' })
  }
  if (!user.is_active) {
    throw createError({ statusCode: 403, message: 'Account is inactive' })
  }
  return user
}

/**
 * Require admin or super admin. Throws 403 otherwise.
 */
export function requireAdmin(event: H3Event): AuthUser {
  const user = requireAuth(event)
  if (!user.is_admin && !user.is_super_admin) {
    throw createError({ statusCode: 403, message: 'Admin access required' })
  }
  return user
}

/**
 * Require super admin. Throws 403 otherwise.
 */
export function requireSuperAdmin(event: H3Event): AuthUser {
  const user = requireAuth(event)
  if (!user.is_super_admin) {
    throw createError({ statusCode: 403, message: 'Super admin access required' })
  }
  return user
}

/**
 * Returns team_id for filtering READ queries.
 *
 * EVERY role reads within their own team — super admins included. A super admin
 * moves between teams by changing their team in Settings, and their reads and
 * writes move together.
 *
 * Super admins used to get null here (= no filter, see every team). That made
 * reads and writes disagree, and the Automated Builder is where it bit: it read
 * every team's employees, training and targets, then saved the result into the
 * super admin's own team — putting another site's people on this site's board.
 * Team scope now has exactly ONE answer.
 *
 * The few genuinely cross-team screens must opt out EXPLICITLY via
 * readsAllTeams(); never by relying on this returning null.
 *
 * ⚠ Still not for stamping new records — use getWriteTeamId() for writes.
 *
 * Throws 403 for an account with no team. Callers treat a null filter as "no
 * filter", so returning null here would have handed a team-less account EVERY
 * team's data — the opposite of what an unassigned account should see. Every
 * user must belong to a team; the create-user form enforces it at the front.
 *
 * Deliberately NOT thrown from requireAuth: /api/auth/me, logout and the teams
 * list don't call this, so a team-less super admin can still sign in and fix
 * themselves in Settings → Change Team instead of being locked out entirely.
 */
export function getTeamFilter(user: AuthUser): string {
  if (!user.team_id) {
    throw createError({
      statusCode: 403,
      message: 'Your account is not assigned to a team. Ask an administrator to assign one.',
    })
  }
  return user.team_id
}

/**
 * Explicit opt-out from team scoping, for the genuinely install-wide screens.
 *
 * A super admin administers users and teams across the whole deployment, so
 * those reads must not be narrowed to their current team. This is a deliberate,
 * named exception so it reads as a decision rather than an oversight — if you
 * are reaching for it anywhere else, you almost certainly want getTeamFilter().
 */
export function readsAllTeams(user: AuthUser): boolean {
  return user.is_super_admin
}

/**
 * Returns the team_id to stamp on records this user CREATES.
 *
 * Always the user's own assigned team — including super admins. This differs
 * from getTeamFilter (used for reads, where super admins get null so they can
 * see every team): a super admin still belongs to a team, and their saves
 * should land in that team so the rest of the team can see them, rather than
 * being orphaned with team_id = NULL.
 *
 * A super admin moves their "write target" by changing their own team
 * assignment in Settings; their reads remain unfiltered (they see all teams).
 *
 * Throws 403 for an account with no team, rather than stamping team_id = NULL.
 * Orphaned NULL rows are invisible to every team-scoped read and have caused
 * real "the data vanished" incidents — refusing the write is far better than
 * silently creating one.
 */
export function getWriteTeamId(user: AuthUser): string {
  if (!user.team_id) {
    throw createError({
      statusCode: 403,
      message: 'Your account is not assigned to a team, so it cannot save data. Ask an administrator to assign one.',
    })
  }
  return user.team_id
}
