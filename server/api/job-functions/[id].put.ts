import { query } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'

/** A cleared number box arrives as '' — Postgres rejects that for an integer. */
const numberOrNull = (v: unknown): number | null => (v === '' || v == null ? null : Number(v))

export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const {
    name,
    color_code,
    sort_order,
    unit_of_measure,
    custom_unit,
    is_active,
    exclude_from_targets,
    lunch_coverage_required,
    break_coverage_required,
    surplus_overflow,
    staffing_priority
  } = body
  // Only touch a nullable field when the caller sent it. The Edit Job Function form
  // stopped sending productivity rate and unit in Sep 2026; written unconditionally,
  // every save would have wiped them. And a cleared "Max people at once" box used to
  // reach Postgres as '' — the save failed while the form closed as if it had worked.
  const sent = (k: string) => Object.prototype.hasOwnProperty.call(body ?? {}, k)

  // Training Matrix target (migration 023): the fewest trained people wanted on shift
  // in any hour the job is worked. Sent on its own by the matrix, never by the form.
  const trainingTarget = numberOrNull(body?.training_target)
  if (trainingTarget !== null && !(Number.isInteger(trainingTarget) && trainingTarget >= 0)) {
    throw createError({ statusCode: 400, message: 'Training target must be a whole number, 0 or more.' })
  }

  const params: unknown[] = [
    name ?? null,
    color_code ?? null,
    numberOrNull(body.productivity_rate),
    sort_order ?? null,
    unit_of_measure ?? null,
    custom_unit ?? null,
    is_active ?? null,
    exclude_from_targets ?? null,
    lunch_coverage_required ?? null,
    break_coverage_required ?? null,
    numberOrNull(body.max_headcount),
    surplus_overflow ?? null,
    staffing_priority ?? null,
    id,
    sent('productivity_rate'),
    sent('unit_of_measure'),
    sent('custom_unit'),
    sent('max_headcount'),
    trainingTarget,
    sent('training_target')
  ]

  let sql = `UPDATE job_functions
     SET name                      = COALESCE($1, name),
         color_code                = COALESCE($2, color_code),
         productivity_rate         = CASE WHEN $15::boolean THEN $3::integer ELSE productivity_rate END,
         sort_order                = COALESCE($4, sort_order),
         unit_of_measure           = CASE WHEN $16::boolean THEN $5::text ELSE unit_of_measure END,
         custom_unit               = CASE WHEN $17::boolean THEN $6::text ELSE custom_unit END,
         is_active                 = COALESCE($7, is_active),
         exclude_from_targets      = COALESCE($8, exclude_from_targets),
         lunch_coverage_required   = COALESCE($9, lunch_coverage_required),
         break_coverage_required   = COALESCE($10, break_coverage_required),
         max_headcount             = CASE WHEN $18::boolean THEN $11::integer ELSE max_headcount END,
         surplus_overflow          = COALESCE($12, surplus_overflow),
         staffing_priority         = COALESCE($13, staffing_priority),
         training_target           = CASE WHEN $20::boolean THEN $19::integer ELSE training_target END,
         updated_at                = NOW()
     WHERE id = $14`

  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }
  sql += ' RETURNING *'


  const result = await query(sql, params)

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Job function not found' })
  }
  return result.rows[0]
})
