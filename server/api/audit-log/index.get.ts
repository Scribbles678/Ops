import { query } from '../../utils/db'
import { requireSupervisor, getTeamFilter } from '../../utils/authorize'

/**
 * The change log, newest first. SUPERVISOR AND ABOVE, team-scoped. Read-only —
 * there is deliberately no way to edit or delete an entry through the API.
 *
 * Query params: entity (comma-separated entity types), employee_id, action,
 *               limit (default 15, max 100), offset
 */
const ENTITIES = ['request', 'pto_day', 'attendance_point', 'performance_note', 'performance_error']
const ACTIONS = ['approve', 'reject', 'delete', 'add', 'edit']

export default defineEventHandler(async (event) => {
  const user = requireSupervisor(event)
  const teamId = getTeamFilter(user)
  const p = getQuery(event)

  const conditions = ['team_id = $1']
  const values: unknown[] = [teamId]

  const entities = String(p.entity ?? '').split(',').map((s) => s.trim()).filter((s) => ENTITIES.includes(s))
  if (entities.length) {
    values.push(entities)
    conditions.push(`entity_type = ANY($${values.length}::text[])`)
  }
  if (p.employee_id) {
    values.push(String(p.employee_id))
    conditions.push(`employee_id = $${values.length}`)
  }
  if (p.action && ACTIONS.includes(String(p.action))) {
    values.push(String(p.action))
    conditions.push(`action = $${values.length}`)
  }

  const limit = Math.min(100, Math.max(1, Number(p.limit) || 15))
  const offset = Math.max(0, Number(p.offset) || 0)
  const where = 'WHERE ' + conditions.join(' AND ')

  const [rows, count] = await Promise.all([
    query<any>(
      `SELECT id, actor_id, actor_name, action, entity_type, entity_id, employee_id, employee_name,
              summary, before, after, created_at
       FROM audit_log ${where}
       ORDER BY created_at DESC
       LIMIT ${limit} OFFSET ${offset}`,
      values
    ),
    query<{ n: string }>(`SELECT count(*)::text AS n FROM audit_log ${where}`, values),
  ])

  return { entries: rows.rows, total: Number(count.rows[0]?.n ?? 0), limit, offset }
})
