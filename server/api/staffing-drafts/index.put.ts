import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'
import { resolveTeamScope } from '../../utils/teamScope'

export interface StaffingSegment {
  start: string
  end: string
  targetHours: number
}

function isValidTime(t: unknown): t is string {
  return typeof t === 'string' && /^\d{1,2}:\d{2}$/.test(t)
}

/**
 * PUT /api/staffing-drafts
 * Body: { job_function_name, segments[], day_start?, day_end?, team_id? (super admin) }
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const body = await readBody(event)
  const {
    job_function_name: jfRaw,
    segments: segmentsRaw,
    day_start: dayStart,
    day_end: dayEnd,
    team_id: bodyTeamId,
  } = body ?? {}

  const teamId = resolveTeamScope(user, bodyTeamId as string | undefined)

  if (!jfRaw || typeof jfRaw !== 'string' || !jfRaw.trim()) {
    throw createError({ statusCode: 400, message: 'job_function_name is required' })
  }
  const jf = jfRaw.trim()

  if (!Array.isArray(segmentsRaw)) {
    throw createError({ statusCode: 400, message: 'segments must be an array' })
  }

  const segments: StaffingSegment[] = []
  for (const s of segmentsRaw) {
    if (!s || typeof s !== 'object') {
      throw createError({ statusCode: 400, message: 'Each segment must be an object' })
    }
    const { start, end, targetHours } = s as Record<string, unknown>
    if (!isValidTime(start) || !isValidTime(end)) {
      throw createError({ statusCode: 400, message: 'Segment start/end must be HH:MM' })
    }
    const th = Number(targetHours)
    if (!Number.isFinite(th) || th < 0.5) {
      throw createError({ statusCode: 400, message: 'Each segment needs targetHours >= 0.5' })
    }
    segments.push({ start, end, targetHours: th })
  }

  const existing = await query<{ id: string }>(
    `SELECT id FROM staffing_day_drafts
     WHERE job_function_name = $1 AND (team_id IS NOT DISTINCT FROM $2)`,
    [jf, teamId]
  )

  if (existing.rows[0]) {
    const upd = await query(
      `UPDATE staffing_day_drafts
       SET segments = $1::jsonb,
           day_start = $2,
           day_end = $3,
           updated_at = NOW()
       WHERE id = $4
       RETURNING id, job_function_name, segments, day_start, day_end, updated_at`,
      [JSON.stringify(segments), dayStart ?? null, dayEnd ?? null, existing.rows[0].id]
    )
    return upd.rows[0]
  }

  const ins = await query(
    `INSERT INTO staffing_day_drafts (team_id, job_function_name, segments, day_start, day_end, updated_at)
     VALUES ($1, $2, $3::jsonb, $4, $5, NOW())
     RETURNING id, job_function_name, segments, day_start, day_end, updated_at`,
    [teamId, jf, JSON.stringify(segments), dayStart ?? null, dayEnd ?? null]
  )
  return ins.rows[0]
})
