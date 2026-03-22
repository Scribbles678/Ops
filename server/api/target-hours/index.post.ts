import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { items } = body as { items: Array<{ job_function_id: string; target_hours: number }> }

  if (!Array.isArray(items) || items.length === 0) {
    throw createError({ statusCode: 400, message: 'items array is required and must not be empty' })
  }

  for (const item of items) {
    const { job_function_id, target_hours } = item
    if (!job_function_id || target_hours === undefined) continue
    await query(
      `INSERT INTO target_hours (job_function_id, target_hours, team_id)
       VALUES ($1, $2, $3)
       ON CONFLICT (job_function_id, team_id)
       DO UPDATE SET target_hours = EXCLUDED.target_hours, updated_at = NOW()`,
      [job_function_id, parseFloat(String(target_hours)) || 0, teamId ?? null]
    )
  }
  return { ok: true }
})
