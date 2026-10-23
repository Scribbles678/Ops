import { transaction } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { logChange, employeeDisplayName, describePtoDay } from '../../utils/auditLog'
import { lockTeamTimeOff, findTimeOffConflict, requestShapeForPto, timeOffLabel } from '../../utils/timeOff'
import { describePto } from '../../../utils/ptoDisplay'

/** What the schedule page's PTO popup writes. A call-in has its own button. */
const EDITABLE_TYPES = ['full_day', 'partial', 'leave_early', 'arrive_late']

/**
 * Change a PTO day in place (the schedule page's PTO popup). Logged to the change log.
 *
 * The popup used to delete the row and add a new one. A row an approved request had
 * created then lost its request, so the request and the new row were BOTH charged —
 * pressing Save on an unchanged day off made it 16 hours. Editing in place keeps the
 * link, and the approved request is updated to match: the hours budget prices the
 * request, not the row (server/utils/ptoUsage.ts).
 *
 * Body: { pto_type, start_time, end_time } in the pto_days storage convention
 * (utils/ptoDisplay.ts). The date is not changed here.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  // Nitro may register the param as 'id' or 'date' depending on sibling route files
  const id = getRouterParam(event, 'id') || getRouterParam(event, 'date')
  if (!id) {
    throw createError({ statusCode: 400, message: 'Missing PTO record ID' })
  }
  const body = await readBody(event)
  const shape = {
    pto_type: body?.pto_type,
    start_time: body?.start_time ?? null,
    end_time: body?.end_time ?? null,
  }
  if (!EDITABLE_TYPES.includes(shape.pto_type)) {
    throw createError({ statusCode: 400, message: `pto_type must be one of: ${EDITABLE_TYPES.join(', ')}` })
  }
  if (!describePto(shape)) {
    throw createError({ statusCode: 400, message: 'Those times do not describe an absence — check the start and end.' })
  }

  return transaction(async (client) => {
    await lockTeamTimeOff(client, teamId)

    const existing = await client.query(
      'SELECT *, pto_date::text AS day FROM pto_days WHERE id = $1 AND team_id = $2',
      [id, teamId]
    )
    if (!existing.rows[0]) {
      throw createError({ statusCode: 404, message: 'PTO record not found' })
    }
    const { day, ...row } = existing.rows[0]
    if (row.pto_type === 'call_in') {
      throw createError({ statusCode: 400, message: 'A call-in is changed with the CI button on their row.' })
    }
    // Save on an unchanged popup: nothing to write or log.
    const sameTime = (a: string | null, b: string | null) => (a ?? '').slice(0, 5) === (b ?? '').slice(0, 5)
    if (row.pto_type === shape.pto_type && sameTime(row.start_time, shape.start_time) && sameTime(row.end_time, shape.end_time)) {
      return row
    }

    const conflict = await findTimeOffConflict(client, {
      teamId,
      employeeId: row.employee_id,
      date: day,
      shape,
      ignorePtoId: id,
    })
    if (conflict) throw createError({ statusCode: 409, message: conflict })

    const updated = await client.query(
      'UPDATE pto_days SET pto_type = $1, start_time = $2, end_time = $3 WHERE id = $4 RETURNING *',
      [shape.pto_type, shape.start_time, shape.end_time, id]
    )

    const request = (await client.query(
      `SELECT id FROM schedule_requests WHERE created_pto_id = $1 AND team_id = $2 AND status = 'approved'`,
      [id, teamId]
    )).rows[0]
    const asRequest = requestShapeForPto(shape)
    if (request && asRequest) {
      await client.query(
        `UPDATE schedule_requests SET request_type = $1, start_time = $2, end_time = $3, updated_at = NOW()
         WHERE id = $4`,
        [asRequest.request_type, asRequest.start_time, asRequest.end_time, request.id]
      )
    }

    const who = await employeeDisplayName(client, row.employee_id)
    await logChange(client, {
      teamId,
      actor: user,
      action: 'edit',
      entity: 'pto_day',
      entityId: id,
      employeeId: row.employee_id,
      employeeName: who,
      summary:
        `Changed ${who}'s ${describePtoDay(row)} to ${timeOffLabel(shape)}` +
        (request ? ' (and the approved request)' : ''),
      before: row,
      after: updated.rows[0],
    })
    return updated.rows[0]
  })
})
