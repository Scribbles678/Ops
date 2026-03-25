import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'
import { resolveTeamScope } from '../../utils/teamScope'

/**
 * GET /api/staffing-drafts?job_function_name=Pick&team_id=optional-for-super-admin
 * Returns saved draft (if any) and live business_rules for that job function (for seeding UI).
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const q = getQuery(event)
  const jobFunctionName = q.job_function_name as string | undefined
  const teamId = resolveTeamScope(user, q.team_id as string | undefined)

  if (!jobFunctionName?.trim()) {
    throw createError({ statusCode: 400, message: 'job_function_name query parameter is required' })
  }

  const jf = jobFunctionName.trim()

  const draftResult = await query(
    `SELECT id, job_function_name, segments, day_start, day_end, updated_at
     FROM staffing_day_drafts
     WHERE job_function_name = $1
       AND (team_id IS NOT DISTINCT FROM $2)`,
    [jf, teamId]
  )

  let liveSql = `SELECT * FROM business_rules
     WHERE job_function_name = $1 AND is_active = true`
  const liveParams: unknown[] = [jf]
  if (teamId) {
    liveParams.push(teamId)
    liveSql += ` AND team_id = $2`
  } else {
    liveSql += ` AND team_id IS NULL`
  }
  liveSql += ` ORDER BY priority ASC, time_slot_start ASC`

  const liveResult = await query(liveSql, liveParams)

  return {
    draft: draftResult.rows[0] ?? null,
    liveRules: liveResult.rows,
    teamScope: teamId,
  }
})
