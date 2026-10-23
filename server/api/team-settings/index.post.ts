import { query, transaction } from '../../utils/db'
import { requireSupervisor, getWriteTeamId } from '../../utils/authorize'
import { isRuleKey, ruleProblem, ruleStoredValue, openWeekendDays } from '../../../utils/requestRuleSettings'

/**
 * Save a team's Request Rules (Settings → Request rules).
 *
 * Body: { settings: { <rule key>: value, ... } } — the whole form, saved in ONE
 * transaction: all of it or none. The page used to send seven requests in a row and
 * stop at the first failure, leaving a team with half its rules saved.
 * The older { setting_key, setting_value } form (one rule) is still accepted, so a
 * page loaded before a deploy can't write around the checks.
 *
 * Every key must be a known rule and every value pass utils/requestRuleSettings.ts.
 * Until Oct 2026 anything was stored as sent: a cleared weekday box became a 0-hour
 * limit that refused every request that day, and "-1" refused every shift change.
 */
export default defineEventHandler(async (event) => {
  const user = requireSupervisor(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)

  const entries: [string, unknown][] =
    body?.settings && typeof body.settings === 'object'
      ? Object.entries(body.settings)
      : body?.setting_key != null
        ? [[body.setting_key, body.setting_value]]
        : []
  if (!entries.length) {
    throw createError({ statusCode: 400, message: 'Send the rules to save as { settings: { ... } }' })
  }

  // Which weekend days the site works decides which daily limits must be filled in:
  // from this save if it sets them, else as stored.
  const sentWeekend = entries.find(([key]) => key === 'open_weekend_days')
  const openWeekend = openWeekendDays(
    sentWeekend
      ? sentWeekend[1]
      : (await query<{ v: string }>(
          `SELECT setting_value AS v FROM team_settings WHERE team_id = $1 AND setting_key = 'open_weekend_days'`,
          [teamId]
        )).rows[0]?.v
  )

  const rows: [string, string][] = []
  for (const [key, value] of entries) {
    if (!isRuleKey(key)) throw createError({ statusCode: 400, message: `Unknown setting: ${key}` })
    const problem = ruleProblem(key, value, openWeekend)
    if (problem) throw createError({ statusCode: 400, message: problem })
    rows.push([key, ruleStoredValue(key, value)])
  }

  const saved = await transaction(async (client) => {
    const result = await client.query(
      `INSERT INTO team_settings (team_id, setting_key, setting_value)
       SELECT $1, k, v FROM unnest($2::text[], $3::text[]) AS t(k, v)
       ON CONFLICT (team_id, setting_key)
       DO UPDATE SET setting_value = EXCLUDED.setting_value, updated_at = NOW()
       RETURNING setting_key, setting_value`,
      [teamId, rows.map((r) => r[0]), rows.map((r) => r[1])]
    )
    return result.rows as { setting_key: string; setting_value: string }[]
  })
  return Object.fromEntries(saved.map((r) => [r.setting_key, r.setting_value]))
})
