import { query } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { LEAVE_COLUMNS, isUuid } from '../../utils/leave'
import { teamToday } from '../../utils/teamTime'

/**
 * Leaves of absence (migration 028), for this team. Team Lead and up: a leave's note
 * can be personal, so the kiosk never reads this (the time-off reads it does get carry
 * leave days without notes — server/utils/leave.ts).
 *
 *   ?employee_id=<id>   every leave that person has had, newest first (the leave
 *                       window on Team Setup, Employee Overview)
 *   (no params)         every leave still running or still to come (Team Setup's badges)
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const employeeId = getQuery(event).employee_id

  if (employeeId) {
    if (!isUuid(employeeId)) {
      throw createError({ statusCode: 400, message: 'employee_id must be an employee id' })
    }
    const r = await query(
      `SELECT ${LEAVE_COLUMNS} FROM employee_leaves WHERE team_id = $1 AND employee_id = $2 ORDER BY start_date DESC`,
      [teamId, employeeId]
    )
    return r.rows
  }

  const today = await teamToday({ query }, teamId)
  const r = await query(
    `SELECT ${LEAVE_COLUMNS} FROM employee_leaves
     WHERE team_id = $1 AND (end_date IS NULL OR end_date >= $2::date)
     ORDER BY start_date`,
    [teamId, today]
  )
  return r.rows
})
