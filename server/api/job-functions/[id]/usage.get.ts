import { query } from "../../../utils/db"
import { requireTeamLead, getTeamFilter } from "../../../utils/authorize"
import { jobFunctionDeleteImpact } from "../../../utils/deleteImpact"
import { teamToday } from "../../../utils/teamTime"

/**
 * What deleting — or deactivating — this job function would erase, change, or be blocked by — shown in
 * Team Setup's delete window before anything happens (server/utils/deleteImpact.ts).
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = String(getRouterParam(event, "id") || "")
  // The viewer's own "today" (their browser's calendar), so "upcoming" means what they'd expect;
  // failing that, the site's (teams.timezone), not the server's UTC date.
  const q = String(getQuery(event).from ?? "")
  const from = /^\d{4}-\d{2}-\d{2}$/.test(q) ? q : await teamToday({ query }, teamId)
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    throw createError({ statusCode: 404, message: "Job function not found" })
  }
  const row = await query<{ name: string }>(
    `SELECT name AS name FROM job_functions WHERE id = $1 AND team_id = $2`,
    [id, teamId]
  )
  if (!row.rowCount) {
    throw createError({ statusCode: 404, message: "Job function not found" })
  }
  return jobFunctionDeleteImpact(id, row.rows[0]!.name, teamId, from)
})
