import { query } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'

/**
 * Permanently delete a shift. This erases every schedule assignment and shift swap
 * on it (ON DELETE CASCADE) — Team Setup shows those counts first
 * (GET /api/shifts/:id/usage) and offers Deactivate instead.
 *
 * Time-off requests reference shifts without a cascade, so a shift that any request
 * names can't be deleted: that used to fail silently. It now says why.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')

  let sql = 'DELETE FROM shifts WHERE id = $1'
  const params: unknown[] = [id]
  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }

  try {
    const result = await query(sql, params)
    if (!result.rowCount) {
      throw createError({ statusCode: 404, message: 'Shift not found' })
    }
  } catch (e: any) {
    if (e?.code !== '23503') throw e
    const refs = await query<{ n: number }>(
      `SELECT count(*)::int AS n FROM schedule_requests
        WHERE original_shift_id = $1 OR requested_shift_id = $1`,
      [id]
    )
    const n = refs.rows[0]?.n ?? 0
    throw createError({
      statusCode: 409,
      message: `${n} time-off request${n === 1 ? '' : 's'} use${n === 1 ? 's' : ''} this shift, so it can't be deleted. Deactivate it instead.`,
    })
  }
  return { success: true }
})
