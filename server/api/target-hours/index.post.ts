import { query } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'
import { assertJobFunctionsOnTeam } from '../../utils/teamOwnership'

/**
 * Save target hours: { items: [{ job_function_id, target_hours }] }, upserted one by
 * one. Team Setup sends a single item per box as it's edited.
 *
 * Every value must be a number of hours, 0 or more, in quarter hours. This used to
 * store anything it couldn't read as 0 — so a cleared box, "-3" or "abc" all saved
 * silently as 0 — and a check here is the only one that holds for every caller.
 */
const MAX_HOURS = 10000

export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const { items } = (body ?? {}) as { items: Array<{ job_function_id: string; target_hours: unknown }> }

  if (!Array.isArray(items) || items.length === 0) {
    throw createError({ statusCode: 400, message: 'items array is required and must not be empty' })
  }
  const clean = items.map((item) => {
    const raw = item?.target_hours
    const hours = raw === '' || raw == null ? NaN : Number(raw)
    if (!item?.job_function_id || !Number.isFinite(hours) || hours < 0 || hours > MAX_HOURS || !Number.isInteger(hours * 4)) {
      throw createError({ statusCode: 400, message: 'Target hours must be a number from 0 to 10,000, in quarter hours (e.g. 7.75).' })
    }
    return { job_function_id: String(item.job_function_id), hours }
  })
  // Only this team's job functions (the ids come from the request body).
  await assertJobFunctionsOnTeam(clean.map((i) => i.job_function_id), teamId)

  for (const { job_function_id, hours } of clean) {
    await query(
      `INSERT INTO target_hours (job_function_id, target_hours, team_id)
       VALUES ($1, $2, $3)
       ON CONFLICT (job_function_id, team_id)
       DO UPDATE SET target_hours = EXCLUDED.target_hours, updated_at = NOW()`,
      [job_function_id, hours, teamId]
    )
  }
  return { ok: true }
})
