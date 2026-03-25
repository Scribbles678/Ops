import { transaction } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { items } = body

  if (!Array.isArray(items) || items.length === 0) {
    throw createError({ statusCode: 400, message: 'items array is required' })
  }

  const results = await transaction(async (client) => {
    const upserted: any[] = []
    for (const item of items) {
      const { job_function_id, hour_start, headcount } = item
      if (!job_function_id || !hour_start || headcount == null) continue

      const result = await client.query(
        `INSERT INTO staffing_targets (job_function_id, hour_start, headcount, team_id)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (job_function_id, hour_start, team_id)
         DO UPDATE SET headcount = $3, updated_at = now()
         RETURNING *`,
        [job_function_id, hour_start, headcount, teamId ?? null]
      )
      upserted.push(result.rows[0])
    }
    return upserted
  })

  return results
})
