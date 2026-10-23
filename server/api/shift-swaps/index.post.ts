import { query } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'
import { assertEmployeeOnTeam, assertShiftsOnTeam } from '../../utils/teamOwnership'

export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const { employee_id, swap_date, original_shift_id, swapped_shift_id, notes } = body

  if (!employee_id || !swap_date || !original_shift_id || !swapped_shift_id) {
    throw createError({ statusCode: 400, message: 'employee_id, swap_date, original_shift_id, and swapped_shift_id are required' })
  }
  // The employee and both shifts must be this team's. The upsert below also only
  // updates this team's row: before Sep 2026 it overwrote another team's swap for
  // that person and day, since (employee_id, swap_date) ignores team.
  await assertEmployeeOnTeam(employee_id, teamId)
  await assertShiftsOnTeam([original_shift_id, swapped_shift_id], teamId)

  const result = await query(
    `INSERT INTO shift_swaps (employee_id, swap_date, original_shift_id, swapped_shift_id, notes, team_id)
     VALUES ($1,$2,$3,$4,$5,$6)
     ON CONFLICT (employee_id, swap_date)
     DO UPDATE SET original_shift_id = EXCLUDED.original_shift_id,
                   swapped_shift_id  = EXCLUDED.swapped_shift_id,
                   notes             = EXCLUDED.notes,
                   updated_at        = NOW()
     WHERE shift_swaps.team_id = EXCLUDED.team_id
     RETURNING *`,
    [employee_id, swap_date, original_shift_id, swapped_shift_id, notes ?? null, teamId]
  )
  if (!result.rows[0]) {
    throw createError({ statusCode: 409, message: 'A shift swap for that person and day belongs to another team.' })
  }
  return result.rows[0]
})
