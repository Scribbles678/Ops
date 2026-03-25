import type { AuthUser } from './authorize'
import { getTeamFilter } from './authorize'

/**
 * Resolves team scope for multi-tenant queries.
 * Super admins may pass ?team_id=... to edit a specific team's draft/rules.
 */
export function resolveTeamScope(
  user: AuthUser,
  queryTeamId: string | undefined | null
): string | null {
  const filter = getTeamFilter(user)
  if (user.is_super_admin && queryTeamId) {
    return queryTeamId
  }
  return filter
}
