import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)

  if (user.is_super_admin) {
    // Super admin sees all teams
    const result = await query(`SELECT * FROM teams ORDER BY name`)
    return result.rows
  } else if (user.team_id) {
    // Regular user sees only their team
    const result = await query(`SELECT * FROM teams WHERE id = $1`, [user.team_id])
    return result.rows
  }
  return []
})
