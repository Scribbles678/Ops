import { query } from '../../../utils/db'
import { requireAdmin, getTeamFilter } from '../../../utils/authorize'

/** Delete a performance note. ADMIN ONLY, team-scoped. */
export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')

  const existing = await query<{ team_id: string | null }>(
    'SELECT team_id FROM performance_notes WHERE id = $1',
    [id]
  )
  if (!existing.rows[0]) {
    throw createError({ statusCode: 404, message: 'Note not found' })
  }
  if (teamId && existing.rows[0].team_id !== teamId) {
    throw createError({ statusCode: 404, message: 'Note not found' })
  }

  await query('DELETE FROM performance_notes WHERE id = $1', [id])
  return { success: true }
})
