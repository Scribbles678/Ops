import { query } from './db'

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
