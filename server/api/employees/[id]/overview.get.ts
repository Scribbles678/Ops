import { query } from '../../../utils/db'
import { requireAuth, getTeamFilter } from '../../../utils/authorize'
import { countBusinessDaysBetween, fmtDate } from '../../../utils/ptoHours'
import { getEmployeeAbsences } from '../../../utils/ptoUsage'

/**
 * Employee Overview — every metric behind the dashboard, aggregated in SQL.
 *
 * Assignment reads UNION schedule_assignments with schedule_assignments_archive.
 * The old Database Cleanup feature moved rows older than 30 days into the archive;
 * it's gone now, but installs that ran it still hold real history there, and
 * omitting it would silently truncate every historical metric.
 *
 * Absence hours come from server/utils/ptoUsage.ts, so they are priced by the same
 * code as the approval rule and the availability strip — the numbers here always
 * agree with the PTO calendar.
 *
 * Query params: from, to (YYYY-MM-DD; default = trailing 12 months)
 */

/** Trailing window the error trend reports on. */
const WINDOW_DAYS = 30
/** Most sample points to plot, so a wide range stays readable. */
const MAX_POINTS = 60

const ASSIGNMENTS_UNION = `
  SELECT employee_id, job_function_id, schedule_date, start_time, end_time, team_id
  FROM schedule_assignments
  UNION ALL
  SELECT employee_id, job_function_id, schedule_date, start_time, end_time, team_id
  FROM schedule_assignments_archive
`

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const viewerTeam = getTeamFilter(user)
  const employeeId = getRouterParam(event, 'id')
  const params = getQuery(event)

  if (!employeeId) {
    throw createError({ statusCode: 400, message: 'Employee id is required' })
  }

  const today = new Date()
  const defaultFrom = new Date(today)
  defaultFrom.setFullYear(defaultFrom.getFullYear() - 1)

  const from = /^\d{4}-\d{2}-\d{2}$/.test(String(params.from ?? ''))
    ? String(params.from)
    : fmtDate(defaultFrom)
  const to = /^\d{4}-\d{2}-\d{2}$/.test(String(params.to ?? ''))
    ? String(params.to)
    : fmtDate(today)

  if (to < from) {
    throw createError({ statusCode: 400, message: '"to" must be on or after "from"' })
  }

  // Employee + team scoping
  const empResult = await query<any>(
    `SELECT e.id, e.first_name, e.last_name, e.is_active, e.team_id, s.name AS shift_name
     FROM employees e LEFT JOIN shifts s ON s.id = e.shift_id
     WHERE e.id = $1`,
    [employeeId]
  )
  const employee = empResult.rows[0]
  if (!employee) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }
  if (viewerTeam && employee.team_id !== viewerTeam) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }
  const teamId: string | null = employee.team_id

  const [mixResult, totalsResult, trainingResult, benchResult, requestResult] = await Promise.all([
    // Work mix: hours + days per job function
    query<any>(
      `SELECT jf.id, jf.name, jf.color_code,
              ROUND(SUM(EXTRACT(EPOCH FROM (a.end_time - a.start_time)) / 3600)::numeric, 2) AS hours,
              COUNT(DISTINCT a.schedule_date)::int AS days
       FROM (${ASSIGNMENTS_UNION}) a
       JOIN job_functions jf ON jf.id = a.job_function_id
       WHERE a.employee_id = $1 AND a.schedule_date BETWEEN $2 AND $3
       GROUP BY jf.id, jf.name, jf.color_code
       ORDER BY hours DESC`,
      [employeeId, from, to]
    ),

    // Totals: days, hours, block count/length
    query<any>(
      `SELECT COUNT(DISTINCT a.schedule_date)::int AS days_scheduled,
              COUNT(*)::int AS blocks,
              COALESCE(ROUND(SUM(EXTRACT(EPOCH FROM (a.end_time - a.start_time)) / 3600)::numeric, 2), 0) AS hours,
              COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (a.end_time - a.start_time)) / 3600)::numeric, 2), 0) AS avg_block_hours,
              MIN(a.schedule_date)::text AS first_date,
              MAX(a.schedule_date)::text AS last_date
       FROM (${ASSIGNMENTS_UNION}) a
       WHERE a.employee_id = $1 AND a.schedule_date BETWEEN $2 AND $3`,
      [employeeId, from, to]
    ),

    // Every trained function, with whether it has ever actually been worked
    // (ever — not just in-range; "trained but never scheduled" is a lifetime fact)
    // and when it was last worked.
    query<any>(
      `SELECT jf.id, jf.name, jf.color_code,
              (SELECT MAX(a.schedule_date)::text FROM (${ASSIGNMENTS_UNION}) a
                WHERE a.employee_id = t.employee_id AND a.job_function_id = t.job_function_id) AS last_worked
       FROM employee_training t
       JOIN job_functions jf ON jf.id = t.job_function_id
       WHERE t.employee_id = $1
       ORDER BY jf.name`,
      [employeeId]
    ),

    // Team benchmark: average functions worked vs trained across active staff
    query<any>(
      `SELECT ROUND(AVG(worked)::numeric, 2) AS avg_worked,
              ROUND(AVG(trained)::numeric, 2) AS avg_trained
       FROM (
         SELECT e.id,
           (SELECT COUNT(DISTINCT a.job_function_id) FROM (${ASSIGNMENTS_UNION}) a
             WHERE a.employee_id = e.id AND a.schedule_date BETWEEN $1 AND $2) AS worked,
           (SELECT COUNT(*) FROM employee_training t WHERE t.employee_id = e.id) AS trained
         FROM employees e
         WHERE e.is_active AND ($3::uuid IS NULL OR e.team_id = $3::uuid)
       ) x`,
      [from, to, teamId]
    ),

    // Requests: status counts, notice given, and the raw rows for the log
    query<any>(
      `SELECT id, request_type, status, request_date::text AS request_date,
              start_time::text AS start_time, end_time::text AS end_time,
              rejection_reason, notes, created_at
       FROM schedule_requests
       WHERE employee_id = $1 AND request_date BETWEEN $2 AND $3
       ORDER BY request_date DESC`,
      [employeeId, from, to]
    ),
  ])

  const totals = totalsResult.rows[0] ?? {}
  const totalHours = Number(totals.hours ?? 0)

  const workMix = mixResult.rows.map((r: any) => ({
    id: r.id,
    name: r.name,
    color: r.color_code,
    hours: Number(r.hours),
    days: r.days,
    share: totalHours > 0 ? Math.round((Number(r.hours) / totalHours) * 1000) / 10 : 0,
  }))

  // --- Skills ---------------------------------------------------------------
  const STALE_DAYS = 90
  const staleCutoff = new Date(today)
  staleCutoff.setDate(staleCutoff.getDate() - STALE_DAYS)
  const staleCutoffStr = fmtDate(staleCutoff)

  const trained = trainingResult.rows.map((r: any) => ({
    id: r.id,
    name: r.name,
    color: r.color_code,
    lastWorked: r.last_worked,
    neverWorked: !r.last_worked,
    stale: !!r.last_worked && r.last_worked < staleCutoffStr,
  }))

  // --- Absences (priced by the shared PTO helpers) --------------------------
  const absences = await getEmployeeAbsences({ query }, employeeId, from, to)

  const byKind: Record<string, { count: number; hours: number }> = {}
  const byWeekday = [0, 0, 0, 0, 0, 0, 0] // Sun..Sat
  for (const a of absences) {
    const bucket = (byKind[a.kind] ??= { count: 0, hours: 0 })
    bucket.count++
    bucket.hours = Math.round((bucket.hours + a.hours) * 100) / 100
    const [y, m, d] = a.date.split('-').map(Number)
    byWeekday[new Date(y, m - 1, d).getDay()]++
  }
  const absenceHours = Math.round(absences.reduce((s, a) => s + a.hours, 0) * 100) / 100
  const callIns = absences.filter((a) => a.kind === 'call_in').length

  // --- Requests -------------------------------------------------------------
  const requests = requestResult.rows
  const approved = requests.filter((r: any) => r.status === 'approved')
  const noticeDays = approved
    .map((r: any) => {
      const [y, m, d] = r.request_date.split('-').map(Number)
      return countBusinessDaysBetween(new Date(r.created_at), new Date(y, m - 1, d))
    })
    .filter((n: number) => n >= 0)
  const avgNotice = noticeDays.length
    ? Math.round((noticeDays.reduce((s: number, n: number) => s + n, 0) / noticeDays.length) * 10) / 10
    : null

  // --- Activity log: requests + call-ins, newest first -----------------------
  const activity = [
    ...requests.map((r: any) => ({
      id: `req-${r.id}`,
      date: r.request_date,
      type: r.request_type,
      status: r.status,
      startTime: r.start_time,
      endTime: r.end_time,
      notes: r.rejection_reason || r.notes || null,
    })),
    ...absences
      .filter((a) => a.source === 'pto_day')
      .map((a, i) => ({
        id: `pto-${a.date}-${i}`,
        date: a.date,
        type: a.kind === 'call_in' ? 'call_in' : `manual_${a.kind}`,
        status: a.kind === 'call_in' ? 'logged' : 'manual',
        startTime: a.startTime,
        endTime: a.endTime,
        notes: a.notes,
      })),
  ].sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0))

  const bench = benchResult.rows[0] ?? {}

  // --- Performance: errors + notes (ADMIN ONLY) -----------------------------
  // Regular Users keep every other panel but must not see review material, so
  // these come back null rather than empty — the UI hides the sections entirely.
  const isAdmin = user.is_admin || user.is_super_admin
  let performance: any = null

  if (isAdmin) {
    // The trend reports a trailing 30-day count, so it needs 30 days of history
    // BEFORE the visible range — otherwise a short period (7d) would compute a
    // "30-day" figure from only 7 days of data and badly undercount.
    // Totals and the entries list are filtered back to [from, to] below.
    const lookbackFrom = (() => {
      const [y, m, d] = from.split('-').map(Number)
      const dt = new Date(y, m - 1, d)
      dt.setDate(dt.getDate() - WINDOW_DAYS)
      return fmtDate(dt)
    })()

    const [errorRows, noteRows] = await Promise.all([
      query<any>(
        `SELECT pe.id, pe.error_date::text AS error_date, pe.error_count, pe.error_type,
                pe.notes, pe.job_function_id, jf.name AS job_function_name,
                COALESCE(u.full_name, u.username) AS logged_by
         FROM performance_errors pe
         LEFT JOIN job_functions jf ON jf.id = pe.job_function_id
         LEFT JOIN user_profiles u ON u.id = pe.created_by
         WHERE pe.employee_id = $1 AND pe.error_date BETWEEN $2 AND $3
         ORDER BY pe.error_date DESC, pe.created_at DESC`,
        [employeeId, lookbackFrom, to]
      ),
      query<any>(
        `SELECT pn.id, pn.note_date::text AS note_date, pn.category, pn.body, pn.tag,
                pn.created_at, pn.updated_at,
                COALESCE(u.full_name, u.username, 'Unknown') AS author
         FROM performance_notes pn
         LEFT JOIN user_profiles u ON u.id = pn.created_by
         WHERE pn.employee_id = $1 AND pn.note_date BETWEEN $2 AND $3
         ORDER BY pn.note_date DESC, pn.created_at DESC`,
        [employeeId, from, to]
      ),
    ])

    // perDay spans the lookback so the rolling window is correct; the visible
    // totals and entries list use only rows inside [from, to].
    const perDay: Record<string, number> = {}
    for (const r of errorRows.rows) {
      perDay[r.error_date] = (perDay[r.error_date] ?? 0) + (Number(r.error_count) || 0)
    }

    const visibleErrors = errorRows.rows.filter((r: any) => r.error_date >= from && r.error_date <= to)

    let totalErrors = 0
    const byFunction: Record<string, { name: string; count: number }> = {}
    for (const r of visibleErrors) {
      const n = Number(r.error_count) || 0
      totalErrors += n
      const key = r.job_function_id || 'none'
      const bucket = (byFunction[key] ??= { name: r.job_function_name || 'Unspecified', count: 0 })
      bucket.count += n
    }

    // Rolling 30-day count.
    //
    // One person logs maybe 1–3 errors a month, so raw per-day counts are mostly
    // zeros with the occasional 1 — noise, not a trend. A trailing 30-day window
    // turns those sparse events into a curve with a readable direction.
    const dates = Object.keys(perDay).sort()
    const trend: { date: string; count: number }[] = []

    if (dates.length) {
      const parse = (s: string) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d) }
      const DAY_MS = 86400000

      // End at today, or the range end if that's earlier; never before the last error.
      const rangeEnd = parse(to)
      const lastError = parse(dates[dates.length - 1])
      let end = today < rangeEnd ? new Date(today) : rangeEnd
      if (end < lastError) end = lastError

      // The plotted span follows the SELECTED PERIOD: ask for 90d and you see 90
      // days, including any flat stretch with no errors — that emptiness is itself
      // information, and trimming it would make recent activity look like the whole
      // story. The exception is the unbounded "All" preset (sent as 2000-01-01),
      // where we anchor to the data instead of plotting decades of nothing.
      const UNBOUNDED_DAYS = 3 * 365
      const rangeStart = parse(from)
      const firstError = parse(dates[0])
      const naturalStart = new Date(firstError)
      naturalStart.setDate(naturalStart.getDate() - WINDOW_DAYS)

      const requestedSpan = Math.round((end.getTime() - rangeStart.getTime()) / DAY_MS)
      let start = requestedSpan > UNBOUNDED_DAYS ? naturalStart : rangeStart
      if (start > end) start = new Date(end)

      // Never plot more than MAX_POINTS worth; clamp the left edge if needed.
      const spanDays = Math.round((end.getTime() - start.getTime()) / DAY_MS)
      const stepDays = Math.max(1, Math.ceil((spanDays + 1) / MAX_POINTS))
      if (spanDays / stepDays > MAX_POINTS) {
        start = new Date(end)
        start.setDate(start.getDate() - (MAX_POINTS - 1) * stepDays)
      }

      const sampleAt = (day: Date) => {
        const windowStart = new Date(day)
        windowStart.setDate(windowStart.getDate() - (WINDOW_DAYS - 1))
        let count = 0
        for (const [d, n] of Object.entries(perDay)) {
          const dd = parse(d)
          if (dd >= windowStart && dd <= day) count += n
        }
        trend.push({ date: fmtDate(day), count })
      }

      for (const cursor = new Date(start); cursor <= end; cursor.setDate(cursor.getDate() + stepDays)) {
        sampleAt(cursor)
      }

      // The walk can stop short of `end`, which would drop the most recent errors
      // and make the endpoint label ("N in last 30d") wrong. Always finish on `end`.
      if (!trend.length || trend[trend.length - 1].date !== fmtDate(end)) {
        sampleAt(end)
      }
    }

    // Tally quick-add tags so repeat incidents are countable, which free text isn't.
    const tagCounts: Record<string, number> = {}
    for (const n of noteRows.rows) {
      if (n.tag) tagCounts[n.tag] = (tagCounts[n.tag] ?? 0) + 1
    }

    performance = {
      totalErrors,
      // Only rows inside [from, to]. The extra lookback rows exist purely to make
      // the rolling window correct and must not appear in the period's own list.
      errorEntries: visibleErrors.length,
      windowDays: WINDOW_DAYS,
      trend,
      current30: trend.length ? trend[trend.length - 1].count : 0,
      peak30: trend.reduce((m, p) => Math.max(m, p.count), 0),
      byFunction: Object.values(byFunction).sort((a, b) => b.count - a.count),
      errors: visibleErrors,
      notes: noteRows.rows,
      tagCounts: Object.entries(tagCounts)
        .map(([tag, count]) => ({ tag, count }))
        .sort((a, b) => b.count - a.count),
    }
  }

  return {
    canSeePerformance: isAdmin,
    performance,
    employee: {
      id: employee.id,
      name: `${employee.last_name}, ${employee.first_name}`,
      shift: employee.shift_name,
      isActive: employee.is_active,
    },
    range: { from, to },
    summary: {
      daysScheduled: totals.days_scheduled ?? 0,
      hoursScheduled: totalHours,
      blocks: totals.blocks ?? 0,
      avgBlockHours: Number(totals.avg_block_hours ?? 0),
      blocksPerDay: totals.days_scheduled
        ? Math.round((totals.blocks / totals.days_scheduled) * 10) / 10
        : 0,
      avgHoursPerDay: totals.days_scheduled
        ? Math.round((totalHours / totals.days_scheduled) * 10) / 10
        : 0,
      firstDate: totals.first_date,
      lastDate: totals.last_date,
      functionsWorked: workMix.length,
      functionsTrained: trained.length,
      absenceHours,
      callIns,
    },
    workMix,
    skills: {
      trained,
      neverWorked: trained.filter((t) => t.neverWorked),
      stale: trained.filter((t) => t.stale),
      teamAvgWorked: bench.avg_worked != null ? Number(bench.avg_worked) : null,
      teamAvgTrained: bench.avg_trained != null ? Number(bench.avg_trained) : null,
      staleDays: STALE_DAYS,
    },
    attendance: {
      byKind,
      byWeekday,
      totalHours: absenceHours,
      requestsSubmitted: requests.length,
      requestsApproved: approved.length,
      requestsRejected: requests.filter((r: any) => r.status === 'rejected').length,
      shiftChanges: approved.filter((r: any) => r.request_type === 'shift_swap').length,
      avgNoticeBusinessDays: avgNotice,
    },
    activity,
  }
})
