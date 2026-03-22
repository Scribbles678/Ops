import { transaction } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { date, assignments } = body as {
    date: string
    assignments: Array<{
      employee_id: string
      job_function_id: string
      shift_id: string
      schedule_date: string
      start_time: string
      end_time: string
      assignment_order?: number
    }>
  }

  if (!date) {
    throw createError({ statusCode: 400, message: 'date is required' })
  }

  if (!Array.isArray(assignments)) {
    throw createError({ statusCode: 400, message: 'assignments array is required' })
  }

  try {
    const inserted = await transaction(async (client) => {
      // 1. Delete existing assignments for this date (same logic as [date].delete.ts)
      let deleteSql = `DELETE FROM schedule_assignments WHERE schedule_date = $1`
      const deleteParams: unknown[] = [date]
      if (teamId) {
        deleteParams.push(teamId)
        deleteSql += ` AND team_id = $${deleteParams.length}`
      }
      await client.query(deleteSql, deleteParams)

      // 2. If no assignments, we're done (replace with empty)
      if (assignments.length === 0) {
        return []
      }

      // 3. Insert each assignment (same validation as assignments-batch)
      const results: any[] = []
      for (let i = 0; i < assignments.length; i++) {
        const a = assignments[i]
        const { employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order = 1 } = a
        if (!employee_id || !job_function_id || !shift_id || !schedule_date || !start_time || !end_time) {
          throw createError({
            statusCode: 400,
            message: `Assignment ${i + 1}: Each assignment must have employee_id, job_function_id, shift_id, schedule_date, start_time, end_time`
          })
        }
        try {
          const result = await client.query(
            `INSERT INTO schedule_assignments
               (employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order, team_id)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
             RETURNING *`,
            [employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order, teamId ?? null]
          )
          results.push(result.rows[0])
        } catch (insertErr: any) {
          const dbMsg = insertErr?.message || String(insertErr)
          console.error(`[schedule-replace] Assignment ${i + 1} failed:`, insertErr)
          throw createError({
            statusCode: 500,
            message: `Assignment ${i + 1} of ${assignments.length} failed: ${dbMsg}`
          })
        }
      }
      return results
    })
    return { inserted, count: inserted.length }
  } catch (e: any) {
    if (e.statusCode) {
      throw e
    }
    const msg =
      e?.message ||
      e?.data?.message ||
      e?.cause?.message ||
      (typeof e === 'string' ? e : 'Failed to replace schedule')
    console.error('[schedule-replace] Error:', e)
    throw createError({ statusCode: 500, message: msg })
  }
})
