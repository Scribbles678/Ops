import { transaction } from '../../utils/db'
import { requireAuth, getWriteTeamId } from '../../utils/authorize'

interface BlockInput {
  start_time: string
  end_time: string
  job_function_id: string
}

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const {
    employee_id,
    job_function_id,
    am_job_function_id,
    pm_job_function_id,
    is_required = false,
    priority = 0,
    notes,
    blocks,
  } = body as {
    employee_id?: string
    job_function_id?: string
    am_job_function_id?: string | null
    pm_job_function_id?: string | null
    is_required?: boolean
    priority?: number
    notes?: string | null
    blocks?: BlockInput[]
  }

  const validBlocks = Array.isArray(blocks)
    ? blocks.filter((b) => b && b.start_time && b.end_time && b.job_function_id && b.end_time > b.start_time)
    : []

  // The base job_function_id is the first block's function when blocks are used,
  // else the explicitly-passed one (legacy am/pm path). It's NOT NULL.
  const baseJfId = validBlocks[0]?.job_function_id ?? job_function_id
  if (!employee_id || !baseJfId) {
    throw createError({ statusCode: 400, message: 'employee_id and at least one job function (block) are required' })
  }

  const result = await transaction(async (client) => {
    const inserted = await client.query(
      `INSERT INTO preferred_assignments (employee_id, job_function_id, am_job_function_id, pm_job_function_id, is_required, priority, notes, team_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [
        employee_id, baseJfId,
        validBlocks.length ? null : (am_job_function_id ?? null),
        validBlocks.length ? null : (pm_job_function_id ?? null),
        is_required, priority, notes ?? null, teamId ?? null,
      ]
    )
    const pa = (inserted.rows as any[])[0]

    for (const b of validBlocks) {
      await client.query(
        `INSERT INTO preferred_assignment_blocks (preferred_assignment_id, start_time, end_time, job_function_id, team_id)
         VALUES ($1,$2,$3,$4,$5)`,
        [pa.id, b.start_time, b.end_time, b.job_function_id, teamId ?? null]
      )
    }
    return pa
  })

  return result
})
