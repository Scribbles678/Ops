import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'
import { setSessionCookie } from '../../utils/jwt'
import { teamsFor } from '../../utils/teamMembership'
import { roleOf } from '../../../utils/roles'

/**
 * Work in another of your teams (the home page's "Working in", the bar on every page,
 * Settings → My account). Body: { team_id, return_to? }.
 *
 * Re-issues THIS browser's session for that team; the account itself is unchanged,
 * so a second computer or phone stays where it was. (A Super Admin's "Change team"
 * used to rewrite the account's team, which quietly moved every device.)
 * Allowed teams: server/utils/teamMembership.ts. A kiosk stays on its own site.
 *
 * The app sends it as a plain form POST (useAuth().switchTeam): the browser asks
 * about unsaved edits before it is sent, and the answer is a redirect back to
 * `return_to` with ?team_switched=1, which tells the browser's other tabs to reload
 * (components/TeamBar.vue). A JSON call gets JSON.
 */
export default defineEventHandler(async (event) => {
  const isForm = (getHeader(event, 'content-type') ?? '').includes('application/x-www-form-urlencoded')
  const body = (await readBody(event)) ?? {}
  // Only a page of this app: never another site, and never an API route.
  const raw = typeof body.return_to === 'string' ? body.return_to : '/'
  const returnTo = /^\/(?!\/|api\/)[^\s\\]*$/.test(raw) ? raw : '/'
  const back = (param: string) => `${returnTo}${returnTo.includes('?') ? '&' : '?'}${param}`

  try {
    const user = requireAuth(event)
    if (roleOf(user) === 'kiosk') {
      throw createError({ statusCode: 403, message: 'A kiosk stays on its own site.' })
    }
    const { team_id } = body
    if (typeof team_id !== 'string' || !team_id) {
      throw createError({ statusCode: 400, message: 'team_id is required' })
    }
    const team = (await teamsFor({ query }, user, user.home_team_id ?? null)).find((t) => t.id === team_id)
    if (!team) {
      throw createError({ statusCode: 403, message: "You don't work in that team. A Super Admin can add it to your account." })
    }

    const session = { ...user, team_id: team.id, team_timezone: team.timezone }
    setSessionCookie(event, session)
    if (isForm) return sendRedirect(event, back('team_switched=1'), 303)
    return { ok: true, user: session }
  } catch (err: any) {
    // A form post would otherwise land on a raw error page; go back and say why.
    if (isForm) return sendRedirect(event, back(`team_switch_failed=${encodeURIComponent(err?.message || 'error')}`), 303)
    throw err
  }
})
