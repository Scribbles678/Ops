import { transaction } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'
import { assertEmployeeOnTeam, assertJobFunctionsOnTeam } from '../../utils/teamOwnership'

/** Replace one employee's training with exactly this set of job functions. */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const { employee_id, job_function_ids } = body

  if (!employee_id || !Array.isArray(job_function_ids)) {
    throw createError({ statusCode: 400, message: 'employee_id and job_function_ids[] are required' })
  }

  // The employee and every job must be on the writer's own team. This used to take
  // any ids, so one team could overwrite — or wipe — another team's training.
  await assertEmployeeOnTeam(employee_id, teamId)
  await assertJobFunctionsOnTeam(job_function_ids, teamId)

  await transaction(async (client) => {
    // Remove training records not in the new list
    if (job_function_ids.length > 0) {
      await client.query(
        `DELETE FROM employee_training
         WHERE employee_id = $1
           AND job_function_id <> ALL($2::uuid[])`,
        [employee_id, job_function_ids]
      )
    } else {
      // Empty array = remove all training for this employee
      await client.query(
        'DELETE FROM employee_training WHERE employee_id = $1',
        [employee_id]
      )
    }

    // Insert new records, ignore duplicates
    if (job_function_ids.length > 0) {
      for (const jfId of job_function_ids) {
        await client.query(
          `INSERT INTO employee_training (employee_id, job_function_id, team_id)
           VALUES ($1, $2, $3)
           ON CONFLICT (employee_id, job_function_id) DO NOTHING`,
          [employee_id, jfId, teamId ?? null]
        )
      }
    }
  })

  return { success: true }
})
