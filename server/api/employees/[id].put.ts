import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'
import { normalizeUpi, isUpiTaken } from '../../utils/upi'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { first_name, last_name, shift_id, is_active } = body
  // Only touch a nullable field when the caller actually sent it. Two callers
  // send different subsets: the shift dropdown on the training tab PUTs
  // { shift_id } alone (null to clear it), and the Add/Edit form PUTs name, UPI
  // and active with NO shift. Until Sep 2026 shift_id was written unconditionally,
  // so saving someone's name from the form silently cleared their shift — and the
  // builder then dropped them with "1 person has no shift assigned".
  const sent = (k: string) => Object.prototype.hasOwnProperty.call(body ?? {}, k)
  const shiftSent = sent('shift_id')
  const upiSent = sent('upi')
  const upi = upiSent ? normalizeUpi(body.upi) : null

  let sql = `UPDATE employees
     SET first_name = COALESCE($1, first_name),
         last_name  = COALESCE($2, last_name),
         shift_id   = CASE WHEN $8::boolean THEN $3::uuid ELSE shift_id END,
         is_active  = COALESCE($4, is_active),
         upi        = CASE WHEN $6::boolean THEN $7::text ELSE upi END,
         updated_at = NOW()
     WHERE id = $5`
  const params: unknown[] = [first_name ?? null, last_name ?? null, shift_id || null, is_active ?? null, id, upiSent, upi, shiftSent]

  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }
  sql += ' RETURNING *'

  try {
    const result = await query(sql, params)
    if (result.rows.length === 0) {
      throw createError({ statusCode: 404, message: 'Employee not found' })
    }
    return result.rows[0]
  } catch (e: any) {
    if (isUpiTaken(e)) throw createError({ statusCode: 409, message: `UPI ${upi} is already assigned to another employee` })
    throw e
  }
})
