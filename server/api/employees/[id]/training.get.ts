import { query } from '../../../utils/db'
import { requireAuth } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const employeeId = getRouterParam(event, 'id')

  const result = await query(
    `SELECT et.*, jf.name AS job_function_name, jf.color_code
     FROM employee_training et
     JOIN job_functions jf ON jf.id = et.job_function_id
     WHERE et.employee_id = $1
     ORDER BY jf.name`,
    [employeeId]
  )
  return result.rows
})
