import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { is_required, priority, notes, am_job_function_id, pm_job_function_id } = body

  const params: unknown[] = [is_required ?? null, priority ?? null, notes ?? null, am_job_function_id ?? null, pm_job_function_id ?? null, id]

  let sql = `UPDATE preferred_assignments
     SET is_required          = COALESCE($1, is_required),
         priority             = COALESCE($2, priority),
         notes                = $3,
         am_job_function_id   = $4,
         pm_job_function_id   = $5,
         updated_at           = NOW()
     WHERE id = $6`

  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }

  sql += ' RETURNING *'

  const result = await query(sql, params)

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Preferred assignment not found' })
  }
  return result.rows[0]
})
