import { query } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'
import { normalizeUpi, isUpiTaken } from '../../utils/upi'
import { assertShiftOnTeam } from '../../utils/teamOwnership'

export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const { first_name, last_name, shift_id, is_active = true } = body
  const upi = normalizeUpi(body.upi)

  if (!first_name?.trim() || !last_name?.trim()) {
    throw createError({ statusCode: 400, message: 'first_name and last_name are required' })
  }
  await assertShiftOnTeam(shift_id, teamId)

  try {
    const result = await query(
      `INSERT INTO employees (first_name, last_name, shift_id, is_active, upi, team_id)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [first_name.trim(), last_name.trim(), shift_id ?? null, is_active, upi, teamId ?? null]
    )
    return result.rows[0]
  } catch (e: any) {
    if (isUpiTaken(e)) throw createError({ statusCode: 409, message: `UPI ${upi} is already assigned to another employee` })
    throw e
  }
})
