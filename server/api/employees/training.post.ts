import { query, transaction } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'
import { assertEmployeeOnTeam } from '../../utils/teamOwnership'

/**
 * Replace one employee's training with exactly this set of job functions.
 *
 * Team Setup no longer uses this — it sends one change at a time to
 * POST /api/employees/:id/training, so a stale screen can't undo someone else's
 * edit. Kept for any other caller.
 *
 * Ids of jobs that aren't on the writer's team are DROPPED rather than refusing the
 * whole save, so the replace also clears out a leftover cross-team row instead of
 * leaving that employee's training impossible to save.
 */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const { employee_id, job_function_ids } = body

  if (!employee_id || !Array.isArray(job_function_ids)) {
    throw createError({ statusCode: 400, message: 'employee_id and job_function_ids[] are required' })
  }
  await assertEmployeeOnTeam(employee_id, teamId)

  const asked = [...new Set(job_function_ids.map(String).filter((id) => UUID.test(id)))]
  const onTeam = asked.length
    ? (await query<{ id: string }>(
        'SELECT id FROM job_functions WHERE id = ANY($1::uuid[]) AND team_id = $2',
        [asked, teamId]
      )).rows.map((r) => r.id)
    : []
  if (onTeam.length !== asked.length) {
    console.warn(`[training] dropped ${asked.length - onTeam.length} job id(s) not on team ${teamId} for employee ${employee_id}`)
  }

  await transaction(async (client) => {
    await client.query(
      `DELETE FROM employee_training
        WHERE employee_id = $1
          AND NOT (job_function_id = ANY($2::uuid[]))`,
      [employee_id, onTeam]
    )
    for (const jfId of onTeam) {
      await client.query(
        `INSERT INTO employee_training (employee_id, job_function_id, team_id)
         VALUES ($1, $2, $3)
         ON CONFLICT (employee_id, job_function_id) DO NOTHING`,
        [employee_id, jfId, teamId]
      )
    }
  })

  return { success: true }
})
