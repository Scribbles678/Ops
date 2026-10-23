import { query } from '../../utils/db'
import { requireSuperAdmin } from '../../utils/authorize'

/**
 * Delete a team — only an EMPTY one.
 *
 * Every team table cascades from `teams`, so deleting a team used to erase a whole
 * site after one "are you sure?": its people, schedules, time off, requests,
 * performance records and its change log (Sep 2026 audit: 20 tables). Now a team
 * that still has anything is refused with a count of what it holds; a site that
 * really must go is emptied deliberately first (or by a DBA with a backup to hand).
 */
const HOLDS: Array<{ table: string; label: string }> = [
  { table: 'user_profiles', label: 'user account' },
  { table: 'employees', label: 'employee' },
  { table: 'shifts', label: 'shift' },
  { table: 'job_functions', label: 'job function' },
  { table: 'schedule_assignments', label: 'scheduled assignment' },
  { table: 'schedule_requests', label: 'request' },
  { table: 'pto_days', label: 'time-off day' },
]

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export default defineEventHandler(async (event) => {
  requireSuperAdmin(event)
  const id = getRouterParam(event, 'id')
  if (!id || !UUID.test(id)) throw createError({ statusCode: 404, message: 'Team not found' })

  // Table names and labels come from the fixed list above, never from the request.
  const counts = await query<{ label: string; n: number }>(
    HOLDS.map((h) => `SELECT '${h.label}' AS label, count(*)::int AS n FROM ${h.table} WHERE team_id = $1`).join(' UNION ALL '),
    [id]
  )
  const held = counts.rows.filter((r) => r.n > 0)
  if (held.length) {
    const list = held.map((r) => `${r.n} ${r.label}${r.n === 1 ? '' : 's'}`).join(', ')
    throw createError({
      statusCode: 409,
      message: `This team still has ${list}. Move or remove them first — deleting a team erases everything it holds.`,
    })
  }

  const result = await query('DELETE FROM teams WHERE id = $1', [id])
  if (!result.rowCount) throw createError({ statusCode: 404, message: 'Team not found' })
  return { success: true }
})
