import { query } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'
import { timeOrNull, checkShiftTimes, checkPair, rethrowShiftError } from '../../utils/shiftInput'

export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const name = String(body?.name ?? '').trim()
  const start = timeOrNull(body?.start_time, 'Start time')
  const end = timeOrNull(body?.end_time, 'End time')
  if (!name || !start || !end) {
    throw createError({ statusCode: 400, message: 'A shift needs a name, a start time and an end time.' })
  }
  checkShiftTimes(start, end)
  const b1s = timeOrNull(body?.break_1_start, 'Break 1 start')
  const b1e = timeOrNull(body?.break_1_end, 'Break 1 end')
  const b2s = timeOrNull(body?.break_2_start, 'Break 2 start')
  const b2e = timeOrNull(body?.break_2_end, 'Break 2 end')
  const ls = timeOrNull(body?.lunch_start, 'Lunch start')
  const le = timeOrNull(body?.lunch_end, 'Lunch end')
  checkPair(b1s, b1e, 'Break 1')
  checkPair(b2s, b2e, 'Break 2')
  checkPair(ls, le, 'Lunch')

  try {
    const result = await query(
      `INSERT INTO shifts
         (name, start_time, end_time, break_1_start, break_1_end, break_2_start, break_2_end,
          lunch_start, lunch_end, is_active, team_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       RETURNING *`,
      [name, start, end, b1s, b1e, b2s, b2e, ls, le, body?.is_active ?? true, teamId]
    )
    return result.rows[0]
  } catch (e: any) {
    rethrowShiftError(e)
  }
})
