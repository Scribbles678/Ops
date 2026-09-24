import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'
import { normalizeUpi } from '../../utils/upi'

/**
 * "Check my requests" at the kiosk: an employee types their UPI and sees their
 * own requests. The gate is enforced HERE, not in the browser — the kiosk account
 * is a real login, so the ordinary requests list would hand it everyone's rows.
 *
 * Scoped to the caller's team (a kiosk account belongs to one site), so a UPI from
 * another site never resolves. Rate-limited per device in server/middleware/
 * 1.rate-limit.ts so nobody can sit at the kiosk cycling through numbers.
 *
 * Returns: upcoming requests plus the last LOOKBACK_DAYS, newest first.
 */
const LOOKBACK_DAYS = 60
const MAX_ROWS = 50

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const upi = normalizeUpi(body?.upi)
  if (!upi) throw createError({ statusCode: 400, message: 'Enter your UPI' })

  const emp = await query<{ id: string; first_name: string; last_name: string }>(
    `SELECT id, first_name, last_name FROM employees
     WHERE team_id = $1 AND upi = $2 AND is_active = true`,
    [teamId, upi]
  )
  if (!emp.rows[0]) {
    throw createError({ statusCode: 404, message: 'No employee with that UPI. Check the number, or ask your supervisor to add it.' })
  }
  const e = emp.rows[0]

  const rows = await query<any>(
    `SELECT id, request_type, status, request_date::text AS request_date,
            start_time::text AS start_time, end_time::text AS end_time,
            rejection_reason, notes, created_at
     FROM schedule_requests
     WHERE employee_id = $1 AND request_date >= CURRENT_DATE - $2::int
     ORDER BY request_date DESC, created_at DESC
     LIMIT $3`,
    [e.id, LOOKBACK_DAYS, MAX_ROWS]
  )

  return {
    employee: { name: `${e.first_name} ${e.last_name}`.trim() },
    lookbackDays: LOOKBACK_DAYS,
    requests: rows.rows,
  }
})
