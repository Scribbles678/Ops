import type { AuthUser } from './authorize'
import { requestTypeLabel, requestTimeLabel } from '../../utils/requestDisplay'
import { ptoTypeLabel, ptoTimeLabel } from '../../utils/ptoDisplay'

/**
 * The change log (migration 022): every manual change to a person's record,
 * with who did it and a sentence a supervisor can read without a decoder.
 *
 * Call `logChange` from INSIDE the transaction that makes the change, passing the
 * transaction client, so a change and its log entry can never come apart. The
 * summary is composed here, once, at write time — the log must still read
 * correctly after the record it describes is gone.
 */
export type AuditAction = 'approve' | 'reject' | 'delete' | 'add' | 'edit'
export type AuditEntity = 'request' | 'pto_day' | 'attendance_point' | 'performance_note' | 'performance_error'

/** A transaction client or the pool's query() — both expose the same call. */
type Runner = { query: (sql: string, params?: unknown[]) => Promise<any> } | ((sql: string, params?: unknown[]) => Promise<any>)
const run = (q: Runner, sql: string, params: unknown[] = []) =>
  typeof q === 'function' ? q(sql, params) : q.query(sql, params)

export interface AuditEntry {
  teamId: string | null
  actor: AuthUser
  action: AuditAction
  entity: AuditEntity
  entityId: string | null
  employeeId: string | null
  employeeName: string | null
  summary: string
  before?: unknown
  after?: unknown
}

export async function logChange(q: Runner, e: AuditEntry): Promise<void> {
  await run(
    q,
    `INSERT INTO audit_log
       (team_id, actor_id, actor_name, action, entity_type, entity_id, employee_id, employee_name, summary, before, after)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
    [
      e.teamId,
      e.actor.id,
      e.actor.full_name || e.actor.username || e.actor.email,
      e.action,
      e.entity,
      e.entityId,
      e.employeeId,
      e.employeeName,
      e.summary,
      e.before == null ? null : JSON.stringify(e.before),
      e.after == null ? null : JSON.stringify(e.after),
    ]
  )
}

/** "First Last" for an employee id, or "an employee" if they are gone. */
export async function employeeDisplayName(q: Runner, employeeId: string | null | undefined): Promise<string> {
  if (!employeeId) return 'an employee'
  const r = await run(q, 'SELECT first_name, last_name FROM employees WHERE id = $1', [employeeId])
  const e = r.rows?.[0]
  return e ? `${e.first_name} ${e.last_name}`.trim() : 'an employee'
}

/** "Sep 15" from a YYYY-MM-DD (or a Date-ish value pg hands back). */
export const shortDate = (d: unknown): string => {
  const s = d instanceof Date ? d.toISOString().slice(0, 10) : String(d ?? '')
  const [y, m, day] = s.slice(0, 10).split('-').map(Number)
  if (!y || !m || !day) return s
  return new Date(y, m - 1, day).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

const clip = (s: unknown, n = 80): string => {
  const t = String(s ?? '').replace(/\s+/g, ' ').trim()
  return t.length > n ? t.slice(0, n - 1) + '…' : t
}

// ---- sentence builders, one per kind of change --------------------------------

export const describeRequest = (r: any): string => {
  const time = requestTimeLabel(r)
  return `${requestTypeLabel(r.request_type)} for ${shortDate(r.request_date)}${time ? ` (${time})` : ''}`
}

export const describePtoDay = (p: any): string => {
  const time = ptoTimeLabel(p)
  return `${ptoTypeLabel(p.pto_type)} on ${shortDate(p.pto_date)}${time ? ` (${time})` : ''}`
}

export const pointsWord = (n: number): string => (n >= 1 ? `${n === 1 ? 'a full' : n} point` : 'a half point')

export const describeNote = (n: any): string =>
  `${n.category} note dated ${shortDate(n.note_date)}: "${clip(n.body)}"`

export const describeError = (e: any, fnName?: string | null): string =>
  `${e.error_count} error${Number(e.error_count) === 1 ? '' : 's'} on ${shortDate(e.error_date)}${fnName ? ` (${fnName})` : ''}${e.error_type ? `, ${e.error_type}` : ''}`
