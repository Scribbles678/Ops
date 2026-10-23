import { transaction } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'
import { logChange, employeeDisplayName, pointsWord, shortDate } from '../../utils/auditLog'
import { assertEmployeeOnTeam } from '../../utils/teamOwnership'

/** The only two values a point can take. Mirrors the CHECK constraint. */
const ALLOWED_POINTS = [0.5, 1]

/**
 * Assign an attendance point (half or full) to an employee on a date. TEAM LEAD
 * AND ABOVE. Logged to the change log.
 *
 * The employee must be on the writer's own team, and the record is stamped with that
 * team. It used to take the EMPLOYEE's team, unchecked, so a lead at one site could
 * file a point against another site's employee — which that site then couldn't
 * remove (Sep 2026 audit).
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

  const teamId = getWriteTeamId(user)
  await assertEmployeeOnTeam(employee_id, teamId)

  return transaction(async (client) => {
    const result = await client.query(
      `INSERT INTO attendance_points (employee_id, point_date, points, notes, team_id, created_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, employee_id, point_date::text AS point_date, points, notes, created_at`,
      [employee_id, point_date, value, note, teamId, user.id]
    )
    const row = result.rows[0]
    const who = await employeeDisplayName(client, employee_id)
    await logChange(client, {
      teamId,
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
