import { query, transaction } from '../../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../../utils/authorize'
import { assertEmployeeOnTeam, assertJobFunctionsOnTeam } from '../../../utils/teamOwnership'

/**
 * Change one employee's training by a DELTA: { add?: uuid[], remove?: uuid[] }.
 * Returns their training afterwards, so the page can take it as the new truth.
 *
 * Team Setup sends one of these per checkbox click. Sending the whole set instead
 * (POST /api/employees/training) meant a screen loaded at 9:00 could silently undo
 * a training another lead added at 9:10, and a failed load looked like "trained on
 * nothing" — so one tick could erase all of someone's training.
 */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const employeeId = getRouterParam(event, 'id')
  const body = await readBody(event)

  const list = (v: unknown) => (Array.isArray(v) ? [...new Set(v.map(String))] : [])
  const add = list(body?.add)
  const remove = list(body?.remove)
  if (!add.length && !remove.length) {
    throw createError({ statusCode: 400, message: 'Nothing to change: send add[] and/or remove[]' })
  }
  if ([...add, ...remove].some((id) => !UUID.test(id))) {
    throw createError({ statusCode: 400, message: 'Job function ids must be uuids' })
  }

  await assertEmployeeOnTeam(employeeId, teamId)
  // Only additions need their jobs checked: a removal can only touch this
  // (already team-checked) employee's own rows.
  await assertJobFunctionsOnTeam(add, teamId)

  await transaction(async (client) => {
    if (remove.length) {
      await client.query(
        'DELETE FROM employee_training WHERE employee_id = $1 AND job_function_id = ANY($2::uuid[])',
        [employeeId, remove]
      )
    }
    for (const jfId of add) {
      await client.query(
        `INSERT INTO employee_training (employee_id, job_function_id, team_id)
         VALUES ($1, $2, $3)
         ON CONFLICT (employee_id, job_function_id) DO NOTHING`,
        [employeeId, jfId, teamId]
      )
    }
  })

  const now = await query<{ job_function_id: string }>(
    `SELECT et.job_function_id
       FROM employee_training et
       JOIN job_functions jf ON jf.id = et.job_function_id AND jf.team_id = $2
      WHERE et.employee_id = $1`,
    [employeeId, teamId]
  )
  return { job_function_ids: now.rows.map((r) => r.job_function_id) }
})
