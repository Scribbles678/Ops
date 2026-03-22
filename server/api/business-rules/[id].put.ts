import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const {
    job_function_name, time_slot_start, time_slot_end,
    min_staff, max_staff, block_size_minutes,
    priority, notes, fan_out_enabled, fan_out_prefix, is_active
  } = body

  const result = await query(
    `UPDATE business_rules
     SET job_function_name  = COALESCE($1, job_function_name),
         time_slot_start    = COALESCE($2, time_slot_start),
         time_slot_end      = COALESCE($3, time_slot_end),
         min_staff          = $4,
         max_staff          = $5,
         block_size_minutes = COALESCE($6, block_size_minutes),
         priority           = COALESCE($7, priority),
         notes              = $8,
         fan_out_enabled    = COALESCE($9, fan_out_enabled),
         fan_out_prefix     = $10,
         is_active          = COALESCE($11, is_active),
         updated_at         = NOW()
     WHERE id = $12
     RETURNING *`,
    [job_function_name ?? null, time_slot_start ?? null, time_slot_end ?? null,
     min_staff ?? null, max_staff ?? null, block_size_minutes ?? null,
     priority ?? null, notes ?? null, fan_out_enabled ?? null, fan_out_prefix ?? null,
     is_active ?? null, id]
  )

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Business rule not found' })
  }
  return result.rows[0]
})
