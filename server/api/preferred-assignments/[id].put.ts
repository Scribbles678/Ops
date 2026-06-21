import { transaction } from '../../utils/db'
import { requireAuth, getTeamFilter, getWriteTeamId } from '../../utils/authorize'

interface BlockInput {
  start_time: string
  end_time: string
  job_function_id: string
}

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const writeTeamId = getWriteTeamId(user)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { is_required, priority, notes, am_job_function_id, pm_job_function_id, job_function_id, blocks } = body as {
    is_required?: boolean
    priority?: number
    notes?: string | null
    am_job_function_id?: string | null
    pm_job_function_id?: string | null
    job_function_id?: string
    blocks?: BlockInput[]
  }

  const hasBlocks = Array.isArray(blocks)
  const validBlocks = hasBlocks
    ? blocks!.filter((b) => b && b.start_time && b.end_time && b.job_function_id && b.end_time > b.start_time)
    : []
  // When replacing with blocks, the base function follows the first block; am/pm cleared.
  const baseJfId = validBlocks[0]?.job_function_id ?? job_function_id ?? null

  const result = await transaction(async (client) => {
    const params: unknown[] = [
      is_required ?? null,
      priority ?? null,
      notes ?? null,
      hasBlocks ? null : (am_job_function_id ?? null),
      hasBlocks ? null : (pm_job_function_id ?? null),
      baseJfId,
      id,
    ]
    let sql = `UPDATE preferred_assignments
       SET is_required        = COALESCE($1, is_required),
           priority           = COALESCE($2, priority),
           notes              = $3,
           am_job_function_id = $4,
           pm_job_function_id = $5,
           job_function_id    = COALESCE($6, job_function_id),
           updated_at         = NOW()
       WHERE id = $7`
    if (teamId) {
      params.push(teamId)
      sql += ` AND team_id = $${params.length}`
    }
    sql += ' RETURNING *'

    const updated = await client.query(sql, params)
    if (updated.rows.length === 0) {
      throw createError({ statusCode: 404, message: 'Preferred assignment not found' })
    }

    // Replace blocks only when a blocks array is supplied.
    if (hasBlocks) {
      await client.query('DELETE FROM preferred_assignment_blocks WHERE preferred_assignment_id = $1', [id])
      for (const b of validBlocks) {
        await client.query(
          `INSERT INTO preferred_assignment_blocks (preferred_assignment_id, start_time, end_time, job_function_id, team_id)
           VALUES ($1,$2,$3,$4,$5)`,
          [id, b.start_time, b.end_time, b.job_function_id, writeTeamId ?? null]
        )
      }
    }
    return (updated.rows as any[])[0]
  })

  return result
})
