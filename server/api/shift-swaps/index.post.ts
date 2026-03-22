import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { employee_id, swap_date, original_shift_id, swapped_shift_id, notes } = body

  if (!employee_id || !swap_date || !original_shift_id || !swapped_shift_id) {
    throw createError({ statusCode: 400, message: 'employee_id, swap_date, original_shift_id, and swapped_shift_id are required' })
  }

  const result = await query(
    `INSERT INTO shift_swaps (employee_id, swap_date, original_shift_id, swapped_shift_id, notes, team_id)
     VALUES ($1,$2,$3,$4,$5,$6)
     ON CONFLICT (employee_id, swap_date)
     DO UPDATE SET original_shift_id = EXCLUDED.original_shift_id,
                   swapped_shift_id  = EXCLUDED.swapped_shift_id,
                   notes             = EXCLUDED.notes,
                   updated_at        = NOW()
     RETURNING *`,
    [employee_id, swap_date, original_shift_id, swapped_shift_id, notes ?? null, teamId ?? null]
  )
  return result.rows[0]
})
