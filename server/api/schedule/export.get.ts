import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

/**
 * Rows for a historical schedule export over a date range.
 *
 * Reads schedule_assignments AND schedule_assignments_archive. The old Database
 * Cleanup feature used to move rows older than 30 days into the archive; that
 * feature is gone, but any rows it already moved are still real history, so a
 * range that straddles the boundary must return both halves.
 *
 * Query params: date_from, date_to (required, YYYY-MM-DD, inclusive)
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const params = getQuery(event)

  const dateFrom = String(params.date_from ?? '')
  const dateTo = String(params.date_to ?? '')

  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateFrom) || !/^\d{4}-\d{2}-\d{2}$/.test(dateTo)) {
    throw createError({ statusCode: 400, message: 'date_from and date_to are required (YYYY-MM-DD)' })
  }
  if (dateTo < dateFrom) {
    throw createError({ statusCode: 400, message: 'date_to must be on or after date_from' })
  }

  const values: unknown[] = [dateFrom, dateTo]
  let teamClause = ''
  if (teamId) {
    values.push(teamId)
    teamClause = `AND sa.team_id = $${values.length}`
  }

  const sql = `
    WITH all_assignments AS (
      SELECT id, employee_id, job_function_id, shift_id, schedule_date,
             assignment_order, start_time, end_time, team_id
      FROM schedule_assignments
      UNION ALL
      SELECT id, employee_id, job_function_id, shift_id, schedule_date,
             assignment_order, start_time, end_time, team_id
      FROM schedule_assignments_archive
    )
    SELECT
      sa.schedule_date::text AS schedule_date,
      e.last_name            AS last_name,
      e.first_name           AS first_name,
      jf.name                AS job_function_name,
      s.name                 AS shift_name,
      sa.start_time::text    AS start_time,
      sa.end_time::text      AS end_time,
      ROUND((EXTRACT(EPOCH FROM (sa.end_time - sa.start_time)) / 3600)::numeric, 2) AS hours,
      sa.assignment_order    AS assignment_order
    FROM all_assignments sa
    LEFT JOIN employees e      ON e.id  = sa.employee_id
    LEFT JOIN job_functions jf ON jf.id = sa.job_function_id
    LEFT JOIN shifts s         ON s.id  = sa.shift_id
    WHERE sa.schedule_date BETWEEN $1 AND $2
      ${teamClause}
    ORDER BY sa.schedule_date, e.last_name, e.first_name, sa.start_time
  `

  const result = await query(sql, values)
  return result.rows
})
