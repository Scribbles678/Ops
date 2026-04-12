import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user) || user.team_id

  if (!teamId) {
    return []
  }

  const result = await query(
    `SELECT id, team_id, blocked_date, reason, created_at
     FROM team_blocked_dates
     WHERE team_id = $1
     ORDER BY blocked_date ASC`,
    [teamId]
  )
  return result.rows
})
