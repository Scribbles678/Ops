import { query } from '../../../utils/db'
import { requireSupervisor, getTeamFilter, readsAllTeams } from '../../../utils/authorize'
import { extraTeamsByUser } from '../../../utils/teamMembership'

/**
 * Settings → Users. A Super Admin: every account. A supervisor: the accounts that
 * work in the team they're in — its own, plus anyone given it as an extra team
 * (migration 027). Each row carries `extra_teams` for the badges.
 */
export default defineEventHandler(async (event) => {
  try {
    const user = requireSupervisor(event)
    // User management is install-wide for a super admin: they must still see
    // every team's users after getTeamFilter became team-scoped for them.
    const teamId = readsAllTeams(user) ? null : getTeamFilter(user)

    let sql = `
      SELECT up.id, up.username, up.email, up.full_name, up.team_id, up.is_admin, up.is_super_admin,
             up.is_team_lead, up.is_display_user, up.is_active, up.last_login, up.created_at,
             json_build_object('id', t.id, 'name', t.name) AS team
      FROM user_profiles up
      LEFT JOIN teams t ON t.id = up.team_id`
    const params: unknown[] = []
    if (teamId) {
      params.push(teamId)
      sql += ` WHERE up.team_id = $1
               OR EXISTS (SELECT 1 FROM user_teams ut WHERE ut.user_id = up.id AND ut.team_id = $1)`
    }
    sql += ` ORDER BY up.username`

    const rows = (await query<any>(sql, params)).rows
    const extras = await extraTeamsByUser({ query }, rows.map((r) => r.id))
    return rows.map((r) => ({ ...r, extra_teams: extras[r.id] ?? [] }))
  } catch (e: any) {
    // Keep a 401 or 403 as it is: turning "your session ended" into a 500 hid it
    // from the app's sign-in-again prompt.
    if (e?.statusCode) throw e
    const msg = e?.message || e?.data?.message || 'Failed to fetch users'
    throw createError({ statusCode: 500, message: msg })
  }
})
