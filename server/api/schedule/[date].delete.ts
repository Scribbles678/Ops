import { query } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'

// Team Lead and up: this wipes a whole day. The kiosk account could call it (Sep 2026 audit).
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
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
