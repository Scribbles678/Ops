import { query } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { timeOrNull, checkShiftTimes, checkPair, rethrowShiftError } from '../../utils/shiftInput'
import { teamToday } from '../../utils/teamTime'

/**
 * Edit a shift. Only fields the caller SENDS are changed. The break and lunch
 * columns used to be written unconditionally, so a one-field save such as
 * { is_active: true } (Team Setup's Reactivate) would have wiped every break and
 * the lunch — changing PTO pricing, the builder's breaks and the schedule shading.
 *
 * Deactivating is refused while active people still have this as their regular
 * shift, or a shift swap onto or off it is coming up: an inactive shift drops them
 * from the display board, the builder and the schedule grid. Move them first.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const body = (await readBody(event)) ?? {}
  const sent = (k: string) => Object.prototype.hasOwnProperty.call(body, k)

  const current = (await query('SELECT * FROM shifts WHERE id = $1 AND team_id = $2', [id, teamId])).rows[0] as any
  if (!current) throw createError({ statusCode: 404, message: 'Shift not found' })

  // The row as it will be after this save: sent fields replace, the rest stay.
  const pick = (k: string, label: string) => (sent(k) ? timeOrNull(body[k], label) : current[k])
  const next = {
    name: sent('name') ? String(body.name ?? '').trim() : current.name,
    start_time: pick('start_time', 'Start time'),
    end_time: pick('end_time', 'End time'),
    break_1_start: pick('break_1_start', 'Break 1 start'),
    break_1_end: pick('break_1_end', 'Break 1 end'),
    break_2_start: pick('break_2_start', 'Break 2 start'),
    break_2_end: pick('break_2_end', 'Break 2 end'),
    lunch_start: pick('lunch_start', 'Lunch start'),
    lunch_end: pick('lunch_end', 'Lunch end'),
    is_active: sent('is_active') && body.is_active != null ? Boolean(body.is_active) : current.is_active,
  }
  if (!next.name || !next.start_time || !next.end_time) {
    throw createError({ statusCode: 400, message: 'A shift needs a name, a start time and an end time.' })
  }
  // Only when the times are being set: an existing overnight shift can still be
  // deactivated or reactivated ({ is_active } alone) — just not saved as overnight again.
  if (sent('start_time') || sent('end_time')) checkShiftTimes(next.start_time, next.end_time)
  checkPair(next.break_1_start, next.break_1_end, 'Break 1')
  checkPair(next.break_2_start, next.break_2_end, 'Break 2')
  checkPair(next.lunch_start, next.lunch_end, 'Lunch')

  if (current.is_active && !next.is_active) {
    const people = (await query<{ n: number }>(
      'SELECT count(*)::int AS n FROM employees WHERE shift_id = $1 AND is_active AND team_id = $2',
      [id, teamId]
    )).rows[0]?.n ?? 0
    // Today onwards at the site (teams.timezone) — the server's own date is UTC,
    // already tomorrow by the evening in US time zones.
    const swaps = (await query<{ n: number }>(
      `SELECT count(*)::int AS n FROM shift_swaps
        WHERE (original_shift_id = $1 OR swapped_shift_id = $1) AND swap_date >= $2::date`,
      [id, await teamToday({ query }, teamId)]
    )).rows[0]?.n ?? 0
    if (people || swaps) {
      const parts = [
        people ? `${people} active ${people === 1 ? 'person has' : 'people have'} it as their shift` : '',
        swaps ? `${swaps} upcoming shift swap${swaps === 1 ? ' uses' : 's use'} it` : '',
      ].filter(Boolean)
      throw createError({
        statusCode: 409,
        message: `${current.name} can't be deactivated yet: ${parts.join(' and ')}. Move them to another shift first.`,
      })
    }
  }

  try {
    const result = await query(
      `UPDATE shifts
          SET name = $1, start_time = $2, end_time = $3,
              break_1_start = $4, break_1_end = $5,
              break_2_start = $6, break_2_end = $7,
              lunch_start = $8, lunch_end = $9,
              is_active = $10
        WHERE id = $11 AND team_id = $12
        RETURNING *`,
      [next.name, next.start_time, next.end_time,
       next.break_1_start, next.break_1_end, next.break_2_start, next.break_2_end,
       next.lunch_start, next.lunch_end, next.is_active, id, teamId]
    )
    if (!result.rows.length) throw createError({ statusCode: 404, message: 'Shift not found' })
    return result.rows[0]
  } catch (e: any) {
    rethrowShiftError(e)
  }
})
