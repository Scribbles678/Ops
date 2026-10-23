import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'
import { teamsFor } from '../../utils/teamMembership'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)

  if (user.is_super_admin) {
    // Super admin sees all teams
    const result = await query(`SELECT * FROM teams ORDER BY name`)
    return result.rows
  }
  // Everyone else: the teams they work in — their own, plus any extra teams a Super
  // Admin gave them (migration 027).
  const ids = (await teamsFor({ query }, user, user.home_team_id ?? null)).map((t) => t.id)
  if (!ids.length) return []
  const result = await query(`SELECT * FROM teams WHERE id = ANY($1::uuid[]) ORDER BY name`, [ids])
  return result.rows
})
