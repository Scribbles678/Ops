import { query } from '../../utils/db'
import { requireAuth, getWriteTeamId } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  // Scope the delete to the writer's own team so a super admin clearing their
  // team's day can't wipe another team's assignments for that date.
  const teamId = getWriteTeamId(user)
  const date = getRouterParam(event, 'date')

  if (!date) {
    throw createError({ statusCode: 400, message: 'Date is required' })
  }

  let sql = `DELETE FROM schedule_assignments WHERE schedule_date = $1`
  const params: unknown[] = [date]

  if (teamId) {
    params.push(teamId)
    sql += ` AND team_id = $${params.length}`
  }

  await query(sql, params)
  return { ok: true }
})
