import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { schedule_date, job_function_id, target_units, notes } = body

  if (!schedule_date || !job_function_id || target_units === undefined) {
    throw createError({ statusCode: 400, message: 'schedule_date, job_function_id, and target_units are required' })
  }

  const result = await query(
    `INSERT INTO daily_targets (schedule_date, job_function_id, target_units, notes, team_id)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (schedule_date, job_function_id, team_id)
     DO UPDATE SET target_units = EXCLUDED.target_units,
                   notes = EXCLUDED.notes,
                   updated_at = NOW()
     RETURNING *`,
    [schedule_date, job_function_id, target_units, notes ?? null, teamId ?? null]
  )
  return result.rows[0]
})
