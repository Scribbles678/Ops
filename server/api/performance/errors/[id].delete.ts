import { query } from '../../../utils/db'
import { requireAdmin, getTeamFilter } from '../../../utils/authorize'

/** Delete a logged error (correcting a mistake). ADMIN ONLY, team-scoped. */
export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')

  const existing = await query<{ team_id: string | null }>(
    'SELECT team_id FROM performance_errors WHERE id = $1',
    [id]
  )
  if (!existing.rows[0]) {
    throw createError({ statusCode: 404, message: 'Error record not found' })
  }
  if (teamId && existing.rows[0].team_id !== teamId) {
    throw createError({ statusCode: 404, message: 'Error record not found' })
  }

  await query('DELETE FROM performance_errors WHERE id = $1', [id])
  return { success: true }
})
