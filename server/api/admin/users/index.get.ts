import { query } from '../../../utils/db'
import { requireAdmin, getTeamFilter } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const teamId = getTeamFilter(user)

  let sql = `
    SELECT id, username, email, full_name, team_id, is_admin, is_super_admin,
           is_display_user, is_active, last_login, created_at,
           row_to_json(t.*) AS team
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
})
