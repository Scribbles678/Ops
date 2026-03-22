import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const {
    name, start_time, end_time,
    break_1_start, break_1_end,
    break_2_start, break_2_end,
    lunch_start, lunch_end,
    is_active
  } = body

  const result = await query(
    `UPDATE shifts
     SET name          = COALESCE($1, name),
         start_time    = COALESCE($2, start_time),
         end_time      = COALESCE($3, end_time),
         break_1_start = $4,
         break_1_end   = $5,
         break_2_start = $6,
         break_2_end   = $7,
         lunch_start   = $8,
         lunch_end     = $9,
         is_active     = COALESCE($10, is_active)
     WHERE id = $11
     RETURNING *`,
    [name ?? null, start_time ?? null, end_time ?? null,
     break_1_start ?? null, break_1_end ?? null,
     break_2_start ?? null, break_2_end ?? null,
     lunch_start ?? null, lunch_end ?? null,
     is_active ?? null, id]
  )

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Shift not found' })
  }
  return result.rows[0]
})
