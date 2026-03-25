import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'
import { resolveTeamScope } from '../../utils/teamScope'

/**
 * GET /api/staffing-drafts/list?team_id=optional
 * Job functions that have a saved draft for this team scope.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const q = getQuery(event)
  const teamId = resolveTeamScope(user, q.team_id as string | undefined)

  const result = await query(
    `SELECT job_function_name, updated_at FROM staffing_day_drafts
     WHERE (team_id IS NOT DISTINCT FROM $1)
     ORDER BY job_function_name ASC`,
    [teamId]
  )

  return { rows: result.rows, teamScope: teamId }
})
