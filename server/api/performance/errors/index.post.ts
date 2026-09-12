import { query, transaction } from '../../../utils/db'
import { requireTeamLead } from '../../../utils/authorize'
import { logChange, employeeDisplayName, describeError } from '../../../utils/auditLog'

/**
 * Log a performance error against an employee. ADMIN ONLY.
 *
 * team_id is taken from the EMPLOYEE, not the logged-in user, so the record lands
 * with the team that owns the employee even when a super admin logs it.
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

  const emp = await query<{ team_id: string | null }>(
    'SELECT team_id FROM employees WHERE id = $1',
    [employee_id]
  )
  if (!emp.rows[0]) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }

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
        emp.rows[0].team_id,
        user.id,
      ]
    )
    const row = result.rows[0]
    const who = await employeeDisplayName(client, employee_id)
    const fn = job_function_id
      ? (await client.query('SELECT name FROM job_functions WHERE id = $1', [job_function_id])).rows[0]?.name
      : null
    await logChange(client, {
      teamId: emp.rows[0].team_id,
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
