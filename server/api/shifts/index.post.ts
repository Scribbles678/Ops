import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const {
    name, start_time, end_time,
    break_1_start, break_1_end,
    break_2_start, break_2_end,
    lunch_start, lunch_end,
    is_active = true
  } = body

  if (!name?.trim() || !start_time || !end_time) {
    throw createError({ statusCode: 400, message: 'name, start_time, and end_time are required' })
  }

  const result = await query(
    `INSERT INTO shifts
       (name, start_time, end_time, break_1_start, break_1_end, break_2_start, break_2_end,
        lunch_start, lunch_end, is_active, team_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
     RETURNING *`,
    [name.trim(), start_time, end_time,
     break_1_start ?? null, break_1_end ?? null,
     break_2_start ?? null, break_2_end ?? null,
     lunch_start ?? null, lunch_end ?? null,
     is_active, teamId ?? null]
  )
  return result.rows[0]
})
