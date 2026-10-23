import { query } from '../../utils/db'
import { requireSuperAdmin } from '../../utils/authorize'
import { DEFAULT_TIMEZONE, isValidTimeZone } from '../../utils/teamTime'
import { checkTeamName } from '../../utils/teamName'

export default defineEventHandler(async (event) => {
  requireSuperAdmin(event)
  const body = await readBody(event)
  const { timezone } = body ?? {}
  const name = await checkTeamName(body?.name)

  // The site's time zone decides "today" for its requests and its display board.
  const tz = timezone || DEFAULT_TIMEZONE
  if (!isValidTimeZone(tz)) {
    throw createError({ statusCode: 400, message: `Unknown time zone: ${tz}` })
  }

  const result = await query(
    `INSERT INTO teams (name, timezone) VALUES ($1, $2) RETURNING *`,
    [name, tz]
  )
  return result.rows[0]
})
