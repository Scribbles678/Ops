import { transaction } from '../../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../../utils/authorize'
import { logChange, employeeDisplayName, describeError } from '../../../utils/auditLog'
import { assertEmployeeOnTeam, assertJobFunctionsOnTeam } from '../../../utils/teamOwnership'

/**
 * Log a performance error against an employee. TEAM LEAD AND ABOVE.
 *
 * The employee (and job function, if given) must be on the writer's own team, and
 * the record is stamped with that team. It used to take the employee's team,
 * unchecked, so one site could log errors against another site's people.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const body = await readBody(event)

  const { employee_id, job_function_id, error_date, error_count, error_type, notes } = body ?? {}

  if (!employee_id || !error_date) {
    throw createError({ statusCode: 400, message: 'employee_id and error_date are required' })
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(error_date))) {
    throw createError({ statusCode: 400, message: 'error_date must be YYYY-MM-DD' })
  }

  const count = error_count == null ? 1 : Number(error_count)
  if (!Number.isInteger(count) || count < 1) {
    throw createError({ statusCode: 400, message: 'error_count must be a whole number of at least 1' })
  }

  const teamId = getWriteTeamId(user)
  await assertEmployeeOnTeam(employee_id, teamId)
  if (job_function_id) await assertJobFunctionsOnTeam([job_function_id], teamId)

  return transaction(async (client) => {
    const result = await client.query(
      `INSERT INTO performance_errors
         (employee_id, job_function_id, error_date, error_count, error_type, notes, team_id, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, employee_id, job_function_id, error_date::text AS error_date,
                 error_count, error_type, notes, created_at`,
      [
        employee_id,
        job_function_id || null,
        error_date,
        count,
        error_type || null,
        notes || null,
        teamId,
        user.id,
      ]
    )
    const row = result.rows[0]
    const who = await employeeDisplayName(client, employee_id)
    const fn = job_function_id
      ? (await client.query('SELECT name FROM job_functions WHERE id = $1', [job_function_id])).rows[0]?.name
      : null
    await logChange(client, {
      teamId,
      actor: user,
      action: 'add',
      entity: 'performance_error',
      entityId: row.id,
      employeeId: employee_id,
      employeeName: who,
      summary: `Logged ${describeError(row, fn)} for ${who}${notes ? `: ${notes}` : ''}`,
      after: row,
    })
    return row
  })
})
