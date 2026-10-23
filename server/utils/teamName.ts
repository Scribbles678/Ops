import { query } from './db'

/** Longest team name; the Settings table and the badges are sized for about this. */
export const MAX_TEAM_NAME_LENGTH = 80

/**
 * A team name for create or rename: trimmed, not blank, not too long, and not
 * already used by another team — compared ignoring case, so "site b" can't sit
 * beside "Site B". A clash used to reach the UNIQUE constraint and come back as
 * "500 Server Error". Returns the trimmed name.
 */
export async function checkTeamName(raw: unknown, exceptTeamId?: string): Promise<string> {
  const name = typeof raw === 'string' ? raw.trim() : ''
  if (!name) throw createError({ statusCode: 400, message: 'Enter a team name.' })
  if (name.length > MAX_TEAM_NAME_LENGTH) {
    throw createError({ statusCode: 400, message: `A team name can be at most ${MAX_TEAM_NAME_LENGTH} characters.` })
  }
  const clash = await query<{ name: string }>(
    'SELECT name FROM teams WHERE lower(name) = lower($1) AND ($2::uuid IS NULL OR id <> $2::uuid) LIMIT 1',
    [name, exceptTeamId ?? null]
  )
  if (clash.rows[0]) {
    throw createError({ statusCode: 409, message: `There is already a team called "${clash.rows[0].name}".` })
  }
  return name
}
