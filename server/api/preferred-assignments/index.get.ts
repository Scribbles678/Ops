import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)

  let sql = `
    SELECT pa.*,
      row_to_json(e.*) AS employee,
      row_to_json(jf.*) AS job_function,
      COALESCE((
        SELECT json_agg(json_build_object(
          'id', b.id,
          'start_time', b.start_time,
          'end_time', b.end_time,
          'job_function_id', b.job_function_id
        ) ORDER BY b.start_time)
        FROM preferred_assignment_blocks b
        WHERE b.preferred_assignment_id = pa.id
      ), '[]'::json) AS blocks
    FROM preferred_assignments pa
    LEFT JOIN employees e ON e.id = pa.employee_id
    LEFT JOIN job_functions jf ON jf.id = pa.job_function_id`

  const params: unknown[] = []

  if (teamId) {
    params.push(teamId)
    sql += ` WHERE pa.team_id = $${params.length}`
  }
  sql += ` ORDER BY pa.priority DESC, e.last_name, e.first_name`

  const result = await query(sql, params)
  return result.rows
})
