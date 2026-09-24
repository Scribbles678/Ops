import { query } from "../../../utils/db"
import { requireTeamLead, getTeamFilter } from "../../../utils/authorize"
import { employeeDeleteImpact } from "../../../utils/deleteImpact"

/**
 * What deleting this employee would erase, change, or be blocked by — shown in
 * Team Setup's delete window before anything happens (server/utils/deleteImpact.ts).
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = String(getRouterParam(event, "id") || "")
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    throw createError({ statusCode: 404, message: "Employee not found" })
  }
  const row = await query<{ name: string }>(
    `SELECT first_name || ' ' || last_name AS name FROM employees WHERE id = $1 AND team_id = $2`,
    [id, teamId]
  )
  if (!row.rowCount) {
    throw createError({ statusCode: 404, message: "Employee not found" })
  }
  return employeeDeleteImpact(id, row.rows[0]!.name)
})
