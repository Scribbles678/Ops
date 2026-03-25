import { query, transaction } from '../../utils/db'
import type { PoolClient } from 'pg'
import { requireAdmin } from '../../utils/authorize'
import { resolveTeamScope } from '../../utils/teamScope'
import type { StaffingSegment } from './index.put'

function timeToMinutes(time: string): number {
  const parts = String(time || '00:00').split(':').map(Number)
  return (parts[0] || 0) * 60 + (parts[1] || 0)
}

function slotHours(start: string, end: string): number {
  const a = timeToMinutes(start)
  const b = timeToMinutes(end)
  if (b <= a) return 0
  return (b - a) / 60
}

/**
 * POST /api/staffing-drafts/publish
 * Replaces non-fan-out staffing rows for one job function with segments from the saved draft.
 * Preserves global-max-only rules (min_staff IS NULL AND max_staff IS NOT NULL) and fan-out rows.
 */
export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const body = await readBody(event)
  const { job_function_name: jfRaw, team_id: bodyTeamId } = body ?? {}

  const teamId = resolveTeamScope(user, bodyTeamId as string | undefined)

  if (!jfRaw || typeof jfRaw !== 'string' || !jfRaw.trim()) {
    throw createError({ statusCode: 400, message: 'job_function_name is required' })
  }
  const jf = jfRaw.trim()

  const draftResult = await query<{ segments: StaffingSegment[] }>(
    `SELECT segments FROM staffing_day_drafts
     WHERE job_function_name = $1 AND (team_id IS NOT DISTINCT FROM $2)`,
    [jf, teamId]
  )

  const row = draftResult.rows[0]
  if (!row || !Array.isArray(row.segments) || row.segments.length === 0) {
    throw createError({
      statusCode: 400,
      message: 'No draft found for this job function. Save a draft in the designer first.',
    })
  }

  const segments = row.segments as StaffingSegment[]
  for (const s of segments) {
    if (slotHours(s.start, s.end) <= 0) {
      throw createError({
        statusCode: 400,
        message: `Invalid segment ${s.start}–${s.end}: end must be after start`,
      })
    }
  }

  await transaction(async (client: PoolClient) => {
    const delParams: unknown[] = [jf]
    let delSql = `DELETE FROM business_rules
      WHERE job_function_name = $1
        AND is_active = true
        AND COALESCE(fan_out_enabled, false) = false
        AND NOT (min_staff IS NULL AND max_staff IS NOT NULL)`
    if (teamId) {
      delParams.push(teamId)
      delSql += ` AND team_id = $2`
    } else {
      delSql += ` AND team_id IS NULL`
    }

    await client.query(delSql, delParams)

    for (const seg of segments) {
      const hours = slotHours(seg.start, seg.end)
      const staffCount = Math.max(1, Math.ceil(seg.targetHours / hours))
      await client.query(
        `INSERT INTO business_rules
           (job_function_name, time_slot_start, time_slot_end, min_staff, max_staff,
            block_size_minutes, priority, notes, fan_out_enabled, fan_out_prefix, team_id, is_active)
         VALUES ($1, $2, $3, $4, $5, 0, 0, NULL, false, NULL, $6, true)`,
        [jf, seg.start, seg.end, staffCount, staffCount, teamId]
      )
    }
  })

  return {
    success: true,
    job_function_name: jf,
    rulesCreated: segments.length,
    team_id: teamId,
  }
})
