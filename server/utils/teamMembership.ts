import { roleOf, type RoleFlags } from '../../utils/roles'

/**
 * Which teams an account may work in (migration 027), in one place.
 *
 *   home team   user_profiles.team_id — where it signs in and whose user list it is on
 *   extra teams user_teams rows, given by a Super Admin (Supervisors and Team Leads)
 *   Super Admin every team
 *   Kiosk       its home team only — it is one screen at one site
 *
 * An account still works in ONE team at a time. The session says which
 * (server/middleware/auth.ts sets user.team_id to it, user.home_team_id to the home
 * team), so every route that scopes by getTeamFilter / getWriteTeamId is unchanged.
 */

interface Queryable {
  query(sql: string, params?: unknown[]): Promise<{ rows: any[] }>
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export interface TeamOption {
  id: string
  name: string
  timezone: string
  /** The account's home team. */
  home: boolean
}

/** Roles that may be given extra teams. A Super Admin already has every team. */
export const canHoldExtraTeams = (u: RoleFlags | null | undefined): boolean => {
  const r = roleOf(u)
  return r === 'supervisor' || r === 'team_lead'
}

/** Every team the account may work in, by name, its home team marked. */
export async function teamsFor(
  db: Queryable,
  user: RoleFlags & { id: string },
  homeTeamId: string | null
): Promise<TeamOption[]> {
  const cols = 'SELECT t.id, t.name, t.timezone, (t.id = $1::uuid) AS home FROM teams t'
  if (user.is_super_admin) {
    return (await db.query(`${cols} ORDER BY t.name`, [homeTeamId])).rows
  }
  if (canHoldExtraTeams(user)) {
    return (await db.query(
      `${cols}
       WHERE t.id = $1::uuid
          OR EXISTS (SELECT 1 FROM user_teams ut WHERE ut.user_id = $2 AND ut.team_id = t.id)
       ORDER BY t.name`,
      [homeTeamId, user.id]
    )).rows
  }
  if (!homeTeamId) return []
  return (await db.query(`${cols} WHERE t.id = $1::uuid`, [homeTeamId])).rows
}

/** An account's home team plus its extra teams, as stored (for the "all its teams" rule). */
export async function accountTeamIds(db: Queryable, userId: string): Promise<string[]> {
  const r = await db.query(
    `SELECT team_id FROM user_profiles WHERE id = $1 AND team_id IS NOT NULL
     UNION SELECT team_id FROM user_teams WHERE user_id = $1`,
    [userId]
  )
  return r.rows.map((x) => x.team_id)
}

/** Extra teams per account, for the user list: { user_id: [{ id, name }] }. */
export async function extraTeamsByUser(db: Queryable, userIds: string[]): Promise<Record<string, { id: string; name: string }[]>> {
  if (!userIds.length) return {}
  const r = await db.query(
    `SELECT ut.user_id, t.id, t.name FROM user_teams ut JOIN teams t ON t.id = ut.team_id
     WHERE ut.user_id = ANY($1::uuid[]) ORDER BY t.name`,
    [userIds]
  )
  const out: Record<string, { id: string; name: string }[]> = {}
  for (const row of r.rows) (out[row.user_id] ??= []).push({ id: row.id, name: row.name })
  return out
}

/**
 * Replace an account's extra teams. The home team is never stored as an extra one.
 * Returns which teams were added and removed (for the change log). Call inside the
 * transaction that changes the account.
 */
export async function setExtraTeams(
  db: Queryable,
  userId: string,
  homeTeamId: string | null,
  teamIds: string[]
): Promise<{ added: string[]; removed: string[] }> {
  if (!Array.isArray(teamIds) || teamIds.some((id) => typeof id !== 'string' || !UUID.test(id))) {
    throw createError({ statusCode: 400, message: 'extra_team_ids must be a list of team ids' })
  }
  const wanted = [...new Set(teamIds)].filter((id) => id !== homeTeamId)
  if (wanted.length) {
    const found = await db.query('SELECT id FROM teams WHERE id = ANY($1::uuid[])', [wanted])
    if (found.rows.length !== wanted.length) {
      throw createError({ statusCode: 400, message: 'One of those teams no longer exists' })
    }
  }
  const before: string[] = (await db.query('SELECT team_id FROM user_teams WHERE user_id = $1', [userId])).rows.map((r) => r.team_id)
  await db.query('DELETE FROM user_teams WHERE user_id = $1 AND NOT (team_id = ANY($2::uuid[]))', [userId, wanted])
  if (wanted.length) {
    await db.query(
      `INSERT INTO user_teams (user_id, team_id) SELECT $1, unnest($2::uuid[])
       ON CONFLICT (user_id, team_id) DO NOTHING`,
      [userId, wanted]
    )
  }
  return {
    added: wanted.filter((id) => !before.includes(id)),
    removed: before.filter((id) => !wanted.includes(id)),
  }
}
