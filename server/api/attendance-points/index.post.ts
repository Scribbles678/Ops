import { query, transaction } from '../../utils/db'
import { requireTeamLead } from '../../utils/authorize'
import { logChange, employeeDisplayName, pointsWord, shortDate } from '../../utils/auditLog'

/** The only two values a point can take. Mirrors the CHECK constraint. */
const ALLOWED_POINTS = [0.5, 1]

/**
 * Assign an attendance point (half or full) to an employee on a date. TEAM LEAD
 * AND ABOVE. Logged to the change log.
 *
 * team_id is taken from the EMPLOYEE, not the logged-in user, so the record lands
 * with the team that owns the employee even when a super admin logs it.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const body = await readBody(event)

  const { employee_id, point_date, points, notes } = body ?? {}

  if (!employee_id || !point_date) {
    throw createError({ statusCode: 400, message: 'employee_id and point_date are required' })
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(point_date))) {
    throw createError({ statusCode: 400, message: 'point_date must be YYYY-MM-DD' })
  }
  const value = Number(points)
  if (!ALLOWED_POINTS.includes(value)) {
    throw createError({ statusCode: 400, message: 'points must be 0.5 or 1' })
  }
  const note = typeof notes === 'string' && notes.trim() ? notes.trim() : null
  if (note && note.length > 2000) {
    throw createError({ statusCode: 400, message: 'notes must be 2000 characters or fewer' })
  }

  const emp = await query<{ team_id: string | null }>(
    'SELECT team_id FROM employees WHERE id = $1',
    [employee_id]
  )
  if (!emp.rows[0]) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }

  return transaction(async (client) => {
    const result = await client.query(
      `INSERT INTO attendance_points (employee_id, point_date, points, notes, team_id, created_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, employee_id, point_date::text AS point_date, points, notes, created_at`,
      [employee_id, point_date, value, note, emp.rows[0].team_id, user.id]
    )
    const row = result.rows[0]
    const who = await employeeDisplayName(client, employee_id)
    await logChange(client, {
      teamId: emp.rows[0].team_id,
      actor: user,
      action: 'add',
      entity: 'attendance_point',
      entityId: row.id,
      employeeId: employee_id,
      employeeName: who,
      summary: `Gave ${who} ${pointsWord(value)} for ${shortDate(point_date)}${note ? `: ${note}` : ''}`,
      after: row,
    })
    return row
  })
})
