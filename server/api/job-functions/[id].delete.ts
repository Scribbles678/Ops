import { query } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'

/**
 * Permanently delete a job function. This erases every schedule assignment on it,
 * past and future, plus its training records and targets (ON DELETE CASCADE) —
 * Team Setup shows those counts first (GET /api/job-functions/:id/usage) and
 * offers Deactivate instead.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')

  let sql = 'DELETE FROM job_functions WHERE id = $1'
  const params: unknown[] = [id]
  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }

  const result = await query(sql, params)
  // Used to report success whatever happened — including for another team's id.
  if (!result.rowCount) {
    throw createError({ statusCode: 404, message: 'Job function not found' })
  }
  return { success: true }
})
