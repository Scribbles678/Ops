import { query } from '../../../utils/db'
import { requireAdmin, getTeamFilter } from '../../../utils/authorize'

const CATEGORIES = ['positive', 'coaching', 'concern', 'general']

/**
 * Edit a performance note (fix a typo, reclassify). ADMIN ONLY, team-scoped.
 *
 * created_by is never reassigned — the original author stays on the record even
 * when another admin edits it, so review material keeps an honest attribution.
 */
export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)

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

  const updates: string[] = []
  const values: unknown[] = []

  if (body?.body != null) {
    if (!String(body.body).trim()) {
      throw createError({ statusCode: 400, message: 'Note body cannot be empty' })
    }
    if (String(body.body).length > 5000) {
      throw createError({ statusCode: 400, message: 'Note is too long (5000 characters max)' })
    }
    values.push(String(body.body).trim())
    updates.push(`body = $${values.length}`)
  }
  if (body?.category != null) {
    if (!CATEGORIES.includes(body.category)) {
      throw createError({ statusCode: 400, message: `category must be one of: ${CATEGORIES.join(', ')}` })
    }
    values.push(body.category)
    updates.push(`category = $${values.length}`)
  }
  if (body?.note_date != null) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(body.note_date))) {
      throw createError({ statusCode: 400, message: 'note_date must be YYYY-MM-DD' })
    }
    values.push(body.note_date)
    updates.push(`note_date = $${values.length}`)
  }

  if (!updates.length) {
    throw createError({ statusCode: 400, message: 'Nothing to update' })
  }

  values.push(id)
  const result = await query(
    `UPDATE performance_notes SET ${updates.join(', ')}
     WHERE id = $${values.length}
     RETURNING id, employee_id, note_date::text AS note_date, category, body, updated_at`,
    values
  )
  return result.rows[0]
})
