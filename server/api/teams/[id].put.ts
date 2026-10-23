import { query } from '../../utils/db'
import { requireSuperAdmin } from '../../utils/authorize'
import { isValidTimeZone } from '../../utils/teamTime'
import { checkTeamName } from '../../utils/teamName'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** Rename a team or change its time zone (Settings → Teams). Sends only what changes. */
export default defineEventHandler(async (event) => {
  requireSuperAdmin(event)
  const id = getRouterParam(event, 'id')
  if (!id || !UUID.test(id)) throw createError({ statusCode: 404, message: 'Team not found' })
  const body = await readBody(event)
  const { timezone } = body ?? {}
  const name = body?.name === undefined ? null : await checkTeamName(body.name, id)

  if (timezone != null && !isValidTimeZone(timezone)) {
    throw createError({ statusCode: 400, message: `Unknown time zone: ${timezone}` })
  }

  const result = await query(
    `UPDATE teams SET name = COALESCE($1, name), timezone = COALESCE($2, timezone), updated_at = NOW()
     WHERE id = $3 RETURNING *`,
    [name, timezone ?? null, id]
  )
  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Team not found' })
  }
  return result.rows[0]
})
