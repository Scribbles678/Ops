import { query } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'

/** A cleared number box arrives as '' — Postgres rejects that for an integer. */
const numberOrNull = (v: unknown): number | null => (v === '' || v == null ? null : Number(v))

export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const {
    name,
    color_code = '#3B82F6',
    productivity_rate,
    sort_order = 0,
    unit_of_measure,
    custom_unit,
    exclude_from_targets = false,
    lunch_coverage_required = false,
    break_coverage_required = false,
    max_headcount,
    surplus_overflow = false,
    staffing_priority = 3
  } = body

  if (!name?.trim()) {
    throw createError({ statusCode: 400, message: 'name is required' })
  }

  const result = await query(
    `INSERT INTO job_functions (name, color_code, productivity_rate, sort_order, unit_of_measure, custom_unit, exclude_from_targets, lunch_coverage_required, break_coverage_required, max_headcount, surplus_overflow, staffing_priority, team_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
     RETURNING *`,
    [name.trim(), color_code, numberOrNull(productivity_rate), sort_order, unit_of_measure ?? null, custom_unit ?? null, !!exclude_from_targets, !!lunch_coverage_required, !!break_coverage_required, numberOrNull(max_headcount), !!surplus_overflow, Number(staffing_priority) || 3, teamId ?? null]
  )
  return result.rows[0]
})
