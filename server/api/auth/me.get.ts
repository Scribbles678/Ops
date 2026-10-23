import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'
import { teamsFor } from '../../utils/teamMembership'

/**
 * Who is signed in, plus the teams they may work in (migration 027): the team
 * switcher on the home page and the "Working in" bar read `teams`.
 * user.team_id is the team this session works in; user.home_team_id their own.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teams = await teamsFor({ query }, user, user.home_team_id ?? null)
  return { user, teams }
})
