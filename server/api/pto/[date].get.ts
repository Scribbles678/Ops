import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'
import { leaveDayRows } from '../../utils/leave'
import { isCalendarDate } from '../../../utils/localDate'

/**
 * Everyone's time off on one date: the pto_days rows, plus a row for each person on
 * a leave of absence that day (server/utils/leave.ts — pto_type 'leave', no notes),
 * so the builder, the schedule page and the display board leave them off all day.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const date = getRouterParam(event, 'date')
  if (!isCalendarDate(date)) {
    throw createError({ statusCode: 400, message: `Invalid date: ${String(date)} (use YYYY-MM-DD)` })
  }

  const [result, leaveDays] = await Promise.all([
    query(`SELECT * FROM pto_days WHERE pto_date = $1 AND team_id = $2`, [date, teamId]),
    leaveDayRows({ query }, teamId, date, date),
  ])
  return [...result.rows, ...leaveDays]
})
