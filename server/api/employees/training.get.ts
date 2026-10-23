import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

/**
 * Every training row on the caller's team: (employee_id, job_function_id).
 *
 * Only rows whose employee AND job function are both on the team. A row stamped
 * with this team but pointing at another team's job (left by the old super-admin
 * bug) used to be returned too; Team Setup then sent it back in a save, which the
 * team check refused — so that employee's training could not be saved at all.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)

  const result = await query(
    `SELECT et.*
       FROM employee_training et
       JOIN employees e      ON e.id  = et.employee_id     AND e.team_id  = $1
       JOIN job_functions jf ON jf.id = et.job_function_id AND jf.team_id = $1
      WHERE et.team_id = $1`,
    [teamId]
  )
  return result.rows
})
