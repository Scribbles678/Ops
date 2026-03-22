import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const {
    job_function_name, time_slot_start, time_slot_end,
    min_staff, max_staff, block_size_minutes = 0,
    priority = 0, notes, fan_out_enabled = false, fan_out_prefix
  } = body

  if (!job_function_name || !time_slot_start || !time_slot_end) {
    throw createError({ statusCode: 400, message: 'job_function_name, time_slot_start, and time_slot_end are required' })
  }

  const result = await query(
    `INSERT INTO business_rules
       (job_function_name, time_slot_start, time_slot_end, min_staff, max_staff,
        block_size_minutes, priority, notes, fan_out_enabled, fan_out_prefix, team_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
     RETURNING *`,
    [job_function_name, time_slot_start, time_slot_end, min_staff ?? null, max_staff ?? null,
     block_size_minutes, priority, notes ?? null, fan_out_enabled, fan_out_prefix ?? null, teamId ?? null]
  )
  return result.rows[0]
})
