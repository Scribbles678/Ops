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
 * Super admins get null (meaning: no team filter, see all teams).
 * Regular users get their assigned team_id.
 *
 * ⚠ Do NOT use this to stamp team_id on NEW records — for super admins it
 * returns null, which orphans the row (no team can see it). Use
 * getWriteTeamId() for writes instead.
 */
export function getTeamFilter(user: AuthUser): string | null {
  if (user.is_super_admin) return null
  return user.team_id
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
 * Returns null only when the user has no team at all (e.g. an unassigned super
 * admin) — in that case writes are intentionally team-less.
 */
export function getWriteTeamId(user: AuthUser): string | null {
  return user.team_id
}
