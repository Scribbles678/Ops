import { query } from '../../../utils/db'
import { requireAuth, getTeamFilter } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)

  const cutoffDate = new Date()
  cutoffDate.setDate(cutoffDate.getDate() - 30)
  const cutoff = cutoffDate.toISOString().split('T')[0]

  const teamWhere = teamId ? ' AND team_id = $2' : ''
  const params: unknown[] = [cutoff]
  if (teamId) params.push(teamId)

  const statsResult = await query(
    `SELECT
      (SELECT COUNT(*) FROM schedule_assignments WHERE 1=1 ${teamWhere}) AS total_assignments,
      (SELECT COUNT(*) FROM schedule_assignments_archive WHERE 1=1 ${teamWhere}) AS total_archived_assignments,
      (SELECT COUNT(*) FROM schedule_assignments WHERE schedule_date < $1 ${teamWhere}) AS assignments_to_cleanup,
      (SELECT MIN(schedule_date)::text FROM schedule_assignments WHERE 1=1 ${teamWhere}) AS oldest_schedule_date,
      (SELECT MAX(schedule_date)::text FROM schedule_assignments WHERE 1=1 ${teamWhere}) AS newest_schedule_date`,
    params
  )

  const r = statsResult.rows[0] || {}
  const teamWhere1 = teamId ? ' AND team_id = $1' : ''
  const archiveParams = teamId ? [teamId] : []

  const totalAssignments = await query(
    `SELECT COUNT(*) AS cnt, MIN(schedule_date)::text AS oldest, MAX(schedule_date)::text AS newest FROM schedule_assignments WHERE 1=1 ${teamWhere1}`,
    archiveParams
  )
  const archiveAssignments = await query(
    `SELECT COUNT(*) AS cnt, MIN(schedule_date)::text AS oldest, MAX(schedule_date)::text AS newest FROM schedule_assignments_archive WHERE 1=1 ${teamWhere1}`,
    archiveParams
  )

  const t = totalAssignments.rows[0]
  const a = archiveAssignments.rows[0]

  return {
    total_assignments: parseInt(String(r.total_assignments || '0'), 10),
    total_archived_assignments: parseInt(String(r.total_archived_assignments || '0'), 10),
    assignments_to_cleanup: parseInt(String(r.assignments_to_cleanup || '0'), 10),
    oldest_schedule_date: t?.oldest || null,
    newest_schedule_date: t?.newest || null,
    status: [
      { table_name: 'schedule_assignments', record_count: parseInt(String(t?.cnt || '0'), 10), oldest_date: t?.oldest || null, newest_date: t?.newest || null },
      { table_name: 'schedule_assignments_archive', record_count: parseInt(String(a?.cnt || '0'), 10), oldest_date: a?.oldest || null, newest_date: a?.newest || null },
    ],
  }
})
