import { query } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'

// Legacy table (nothing reads business_rules any more), but the route is still live:
// until Sep 2026 it deleted any team's rule by id, for any signed-in account.
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const result = await query('DELETE FROM business_rules WHERE id = $1 AND team_id = $2', [id, teamId])
  if (!result.rowCount) throw createError({ statusCode: 404, message: 'Business rule not found' })
  return { success: true }
})
