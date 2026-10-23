import { query } from './db'
import { getTeamFilter, type AuthUser } from './authorize'
import { accountTeamIds, teamsFor } from './teamMembership'

/**
 * Refuse ids from another team in a WRITE. Reads are already team-scoped; these
 * cover the ids a request BODY carries — the shift on an employee, the job
 * functions in a training list or a target — which were stored exactly as sent,
 * so one team could point its rows at (or overwrite) another team's data.
 *
 * `teamId` is the writer's own team, from getWriteTeamId / getTeamFilter — both
 * return a string or throw, so it is required here. A missing team fails closed
 * (403) rather than skipping the check, which could only ever hide a bug.
 */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const notOnTeam = (what: string) => createError({ statusCode: 400, message: `${what} is not on your team` })

const requireTeam = (teamId: string) => {
  if (!teamId) throw createError({ statusCode: 403, message: 'No team to check against' })
}

export async function assertEmployeeOnTeam(employeeId: unknown, teamId: string): Promise<void> {
  requireTeam(teamId)
  if (typeof employeeId !== 'string' || !UUID.test(employeeId)) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }
  const r = await query('SELECT 1 FROM employees WHERE id = $1 AND team_id = $2', [employeeId, teamId])
  if (!r.rowCount) throw createError({ statusCode: 404, message: 'Employee not found' })
}

/** A null/empty shift ("no shift") is allowed. */
export async function assertShiftOnTeam(shiftId: unknown, teamId: string): Promise<void> {
  requireTeam(teamId)
  if (shiftId == null || shiftId === '') return
  if (typeof shiftId !== 'string' || !UUID.test(shiftId)) throw notOnTeam('That shift')
  const r = await query('SELECT 1 FROM shifts WHERE id = $1 AND team_id = $2', [shiftId, teamId])
  if (!r.rowCount) throw notOnTeam('That shift')
}

export async function assertJobFunctionsOnTeam(ids: unknown[], teamId: string): Promise<void> {
  requireTeam(teamId)
  if (!ids.length) return
  const unique = [...new Set(ids.map(String))]
  if (unique.some((id) => !UUID.test(id))) throw notOnTeam('A job function')
  const r = await query<{ n: number }>(
    'SELECT count(*)::int AS n FROM job_functions WHERE id = ANY($1::uuid[]) AND team_id = $2',
    [unique, teamId]
  )
  if ((r.rows[0]?.n ?? 0) !== unique.length) throw notOnTeam('A job function')
}

/** Tables whose ids may be checked below. A fixed list: the name goes into the SQL. */
type TeamTable = 'employees' | 'job_functions' | 'shifts'

/**
 * Every id in `ids` must be a row of `table` on `teamId`. Null/empty entries are
 * skipped (optional references); anything else that isn't on the team is refused.
 */
async function assertAllOnTeam(table: TeamTable, ids: unknown[], teamId: string, what: string): Promise<void> {
  requireTeam(teamId)
  const unique = [...new Set(ids.filter((v) => v != null && v !== '').map(String))]
  if (!unique.length) return
  if (unique.some((id) => !UUID.test(id))) throw notOnTeam(what)
  const r = await query<{ n: number }>(
    `SELECT count(*)::int AS n FROM ${table} WHERE id = ANY($1::uuid[]) AND team_id = $2`,
    [unique, teamId]
  )
  if ((r.rows[0]?.n ?? 0) !== unique.length) throw notOnTeam(what)
}

export const assertEmployeesOnTeam = (ids: unknown[], teamId: string) => assertAllOnTeam('employees', ids, teamId, 'An employee')
export const assertShiftsOnTeam = (ids: unknown[], teamId: string) => assertAllOnTeam('shifts', ids, teamId, 'A shift')

/**
 * Schedule rows (one assignment, a batch, a replaced day): every employee, job
 * function and shift they name must be on the writer's team. Without this a team
 * could put another team's people on its board, and — because the overlap check
 * looks across teams — block that team's own save for the day.
 */
export async function assertScheduleRowsOnTeam(
  rows: Array<{ employee_id?: unknown; job_function_id?: unknown; shift_id?: unknown }>,
  teamId: string
): Promise<void> {
  await assertEmployeesOnTeam(rows.map((r) => r.employee_id), teamId)
  await assertAllOnTeam('job_functions', rows.map((r) => r.job_function_id), teamId, 'A job function')
  await assertShiftsOnTeam(rows.map((r) => r.shift_id), teamId)
}

/**
 * User accounts (Settings → Users). A super admin manages every account. A
 * supervisor manages their own site's: the accounts that work in the team they're
 * in, other than super admins — so each site runs its own people without reaching
 * another site's accounts or the install's administrators. Another team's account
 * is "not found", so account ids can't be probed across sites.
 *
 * An account with extra teams (migration 027) is changed only by a Super Admin or
 * a supervisor who works in EVERY one of its teams: Site B's supervisor can't
 * deactivate, demote or reset the regional supervisor who also runs Memphis.
 */
export async function assertAccountManageable(actor: AuthUser, userId: unknown): Promise<void> {
  if (typeof userId !== 'string' || !UUID.test(userId)) {
    throw createError({ statusCode: 404, message: 'User not found' })
  }
  const r = await query<{ is_super_admin: boolean }>('SELECT is_super_admin FROM user_profiles WHERE id = $1', [userId])
  const target = r.rows[0]
  if (!target) throw createError({ statusCode: 404, message: 'User not found' })
  if (actor.is_super_admin) return

  const targetTeams = await accountTeamIds({ query }, userId)
  if (!targetTeams.includes(getTeamFilter(actor))) throw createError({ statusCode: 404, message: 'User not found' })
  if (target.is_super_admin) {
    throw createError({ statusCode: 403, message: "Only a Super Admin can change a Super Admin's account" })
  }
  const mine = new Set((await teamsFor({ query }, actor, actor.home_team_id ?? null)).map((t) => t.id))
  const outside = targetTeams.filter((id) => !mine.has(id))
  if (outside.length) {
    const names = (await query<{ name: string }>('SELECT name FROM teams WHERE id = ANY($1::uuid[]) ORDER BY name', [outside])).rows.map((t) => t.name)
    throw createError({
      statusCode: 403,
      message: `This account also works in ${names.join(', ')}. Only a Super Admin, or a supervisor of all its teams, can change it.`,
    })
  }
}
