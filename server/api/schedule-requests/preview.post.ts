import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'
import { evaluateRequest, loadTeamSettings } from '../../utils/requestRules'

/**
 * Dry run: what would happen if these dates were submitted?
 *
 * Writes nothing. Runs the exact same rule engine the real submit runs
 * (server/utils/requestRules.ts), so the modal can warn about days that would be
 * refused BEFORE anything is committed — instead of silently auto-approving the
 * good days and leaving the user to discover the rest afterwards.
 *
 * Body: { employee_id, request_type, dates: string[], start_time?, end_time? }
 * Returns: { results: [{ date, status, rejectionReason, requestedHours, cap, usedHours }] }
 *
 * Caveat: this is a point-in-time answer. Another admin can consume the day's budget
 * between preview and submit, so the submit re-runs the rules and stays authoritative.
 */
export default defineEventHandler(async (event) => {
  requireAuth(event)
  const body = await readBody(event)
  const { employee_id, request_type, dates, start_time, end_time } = body ?? {}

  if (!employee_id || !request_type || !Array.isArray(dates) || dates.length === 0) {
    throw createError({
      statusCode: 400,
      message: 'employee_id, request_type and a non-empty dates array are required',
    })
  }
  if (dates.length > 366) {
    throw createError({ statusCode: 400, message: 'Date range too large (max 366 days)' })
  }
  for (const d of dates) {
    if (typeof d !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(d)) {
      throw createError({ statusCode: 400, message: `Invalid date in range: ${d}` })
    }
  }

  const empResult = await query<{ team_id: string | null }>(
    'SELECT team_id FROM employees WHERE id = $1',
    [employee_id]
  )
  if (!empResult.rows[0]) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }
  const teamId = empResult.rows[0].team_id

  const settings = await loadTeamSettings({ query }, teamId)

  // Evaluate each date independently — the PTO budget is per-day, so days in a range
  // don't interact. Sequential rather than parallel to keep pool usage predictable.
  const results = []
  for (const date of dates) {
    const verdict = await evaluateRequest(
      { query },
      teamId,
      settings,
      { employee_id, request_type, request_date: date, start_time, end_time }
    )
    results.push({
      date,
      status: verdict.status,
      rejectionReason: verdict.rejectionReason,
      requestedHours: verdict.requestedHours,
      cap: verdict.cap,
      usedHours: verdict.usedHours,
    })
  }

  return {
    results,
    approvedCount: results.filter((r) => r.status === 'approved').length,
    rejectedCount: results.filter((r) => r.status === 'rejected').length,
  }
})
