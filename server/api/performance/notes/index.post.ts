import { query } from '../../../utils/db'
import { requireAdmin } from '../../../utils/authorize'

const CATEGORIES = ['positive', 'coaching', 'concern', 'general']

/**
 * Write a performance note. ADMIN ONLY.
 *
 * Authorship is stamped from the session, never from the request body — a note
 * used in a review has to carry a trustworthy author.
 */
export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const body = await readBody(event)

  const { employee_id, note_date, category, body: noteBody, tag } = body ?? {}

  if (!employee_id || !noteBody || !String(noteBody).trim()) {
    throw createError({ statusCode: 400, message: 'employee_id and a non-empty note body are required' })
  }
  if (String(noteBody).length > 5000) {
    throw createError({ statusCode: 400, message: 'Note is too long (5000 characters max)' })
  }

  const cat = category || 'general'
  if (!CATEGORIES.includes(cat)) {
    throw createError({ statusCode: 400, message: `category must be one of: ${CATEGORIES.join(', ')}` })
  }

  const date = note_date || new Date().toISOString().split('T')[0]
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(date))) {
    throw createError({ statusCode: 400, message: 'note_date must be YYYY-MM-DD' })
  }

  const emp = await query<{ team_id: string | null }>(
    'SELECT team_id FROM employees WHERE id = $1',
    [employee_id]
  )
  if (!emp.rows[0]) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }

  // Tag is set by the quick-add buttons so repeat incidents can be tallied.
  // Hand-typed notes leave it null.
  if (tag != null && String(tag).length > 60) {
    throw createError({ statusCode: 400, message: 'tag is too long (60 characters max)' })
  }

  const result = await query(
    `INSERT INTO performance_notes (employee_id, note_date, category, body, tag, team_id, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, employee_id, note_date::text AS note_date, category, body, tag, created_at`,
    [employee_id, date, cat, String(noteBody).trim(), tag || null, emp.rows[0].team_id, user.id]
  )
  return result.rows[0]
})
