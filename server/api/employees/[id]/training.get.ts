import { query } from '../../../utils/db'
import { requireAuth, getTeamFilter } from '../../../utils/authorize'
import { assertEmployeeOnTeam } from '../../../utils/teamOwnership'

/**
 * One employee's training, with job names. Team-scoped: this used to answer for
 * any employee id, so any team could read another team's training.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const employeeId = getRouterParam(event, 'id')
  await assertEmployeeOnTeam(employeeId, teamId)

  const result = await query(
    `SELECT et.*, jf.name AS job_function_name, jf.color_code
       FROM employee_training et
       JOIN job_functions jf ON jf.id = et.job_function_id AND jf.team_id = $2
      WHERE et.employee_id = $1
      ORDER BY jf.name`,
    [employeeId, teamId]
  )
  return result.rows
})
