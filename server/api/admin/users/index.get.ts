import { query } from '../../../utils/db'
import { requireSupervisor, getTeamFilter, readsAllTeams } from '../../../utils/authorize'

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
      sql += ` WHERE up.team_id = $${params.length}`
    }
    sql += ` ORDER BY up.username`

    const result = await query(sql, params)
    return result.rows
  } catch (e: any) {
    const msg = e?.message || e?.data?.message || 'Failed to fetch users'
    throw createError({ statusCode: 500, message: msg })
  }
})
