import { query } from "../../../utils/db"
import { requireTeamLead, getTeamFilter } from "../../../utils/authorize"
import { shiftDeleteImpact } from "../../../utils/deleteImpact"

/**
 * What deleting this shift would erase, change, or be blocked by — shown in
 * Team Setup's delete window before anything happens (server/utils/deleteImpact.ts).
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = String(getRouterParam(event, "id") || "")
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    throw createError({ statusCode: 404, message: "Shift not found" })
  }
  const row = await query<{ name: string }>(
    `SELECT name AS name FROM shifts WHERE id = $1 AND team_id = $2`,
    [id, teamId]
  )
  if (!row.rowCount) {
    throw createError({ statusCode: 404, message: "Shift not found" })
  }
  return shiftDeleteImpact(id, row.rows[0]!.name)
})
