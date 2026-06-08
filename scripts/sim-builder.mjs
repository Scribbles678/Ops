// Headless harness to validate a redesigned schedule builder against REAL DB inputs.
// Run: node scripts/sim-builder.mjs 2026-06-08
// Does NOT write anything — read-only sim that prints quality metrics.

import pkg from 'pg'
const { Client } = pkg

const DATE = process.argv[2] || '2026-06-08'
const CONN = 'postgresql://postgres:postgres@localhost:5433/scheduling'

const MIN_BLOCK = 30
const MAX_FUNCTIONS = 4 // soft cap — only exceeded to cover a scarce gap

const t2m = (t) => { const p = String(t).split(':').map(Number); return (p[0] || 0) * 60 + (p[1] || 0) }
const m2t = (m) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`
const hoursCovered = (start, end) => {
  const out = []
  const first = Math.floor(start / 60) * 60
  for (let h = first; h < end; h += 60) if (h + 60 > start && h < end) out.push(m2t(h))
  return out
}

// ---- availability helpers ----
const splitAroundBreaks = (start, end, breaks) => {
  if (end <= start) return []
  let segs = [{ start, end }]
  for (const b of breaks) {
    const next = []
    for (const s of segs) {
      if (b.end <= s.start || b.start >= s.end) next.push(s)
      else { if (b.start > s.start) next.push({ start: s.start, end: b.start }); if (b.end < s.end) next.push({ start: b.end, end: s.end }) }
    }
    segs = next
  }
  return segs.filter((s) => s.end - s.start >= MIN_BLOCK)
}

const carve = (windows, aStart, aEnd) => {
  const out = []
  for (const w of windows) {
    if (aEnd <= w.start || aStart >= w.end) out.push(w)
    else { if (aStart > w.start) out.push({ start: w.start, end: aStart }); if (aEnd < w.end) out.push({ start: aEnd, end: w.end }) }
  }
  return out.filter((w) => w.end - w.start > 0)
}

async function main() {
  const c = new Client({ connectionString: CONN }); await c.connect()
  const employees = (await c.query("select id, first_name, last_name, shift_id from employees where is_active is not false")).rows
  const shifts = (await c.query('select * from shifts')).rows
  const jobFunctions = (await c.query('select * from job_functions')).rows
  const training = (await c.query('select employee_id, job_function_id from employee_training')).rows
  const targets = (await c.query('select job_function_id, hour_start, headcount from staffing_targets where is_active is not false')).rows
  const prefs = (await c.query('select * from preferred_assignments')).rows
  const pto = (await c.query('select * from pto_days where pto_date=$1', [DATE])).rows
  const dbAssigns = (await c.query('select employee_id, job_function_id, start_time, end_time from schedule_assignments where schedule_date=$1', [DATE])).rows
  await c.end()

  const shiftById = new Map(shifts.map((s) => [s.id, s]))
  const jfById = new Map(jobFunctions.map((j) => [j.id, j]))
  const trainedFns = {}
  for (const t of training) (trainedFns[t.employee_id] ??= []).push(t.job_function_id)
  const ptoBy = {}; for (const p of pto) ptoBy[p.employee_id] = p
  const prefBy = {}; for (const p of prefs) { (prefBy[p.employee_id] ??= {})[p.job_function_id] = p }

  // ---- prep employees: availability windows (break-free, PTO-clipped) ----
  const emps = []
  for (const e of employees) {
    const s = shiftById.get(e.shift_id); if (!s) continue
    const trained = trainedFns[e.id]; if (!trained || !trained.length) continue
    const breaks = []
    if (s.break_1_start && s.break_1_end) breaks.push({ start: t2m(s.break_1_start), end: t2m(s.break_1_end) })
    if (s.break_2_start && s.break_2_end) breaks.push({ start: t2m(s.break_2_start), end: t2m(s.break_2_end) })
    let amStart = t2m(s.start_time), amEnd = s.lunch_start ? t2m(s.lunch_start) : t2m(s.end_time)
    let pmStart = s.lunch_end ? t2m(s.lunch_end) : null, pmEnd = s.lunch_end ? t2m(s.end_time) : null
    const p = ptoBy[e.id]
    if (p) {
      if (p.pto_type === 'full_day' || (!p.start_time && !p.end_time)) continue
      if (p.start_time && p.end_time) {
        const ps = t2m(p.start_time), pe = t2m(p.end_time)
        if (ps <= amStart && pe > amStart) amStart = Math.min(pe, amEnd); else if (ps > amStart && ps < amEnd) amEnd = ps
        if (pmStart != null) { if (ps <= pmStart && pe > pmStart) pmStart = Math.min(pe, pmEnd); else if (ps > pmStart && ps < pmEnd) pmEnd = ps }
      }
    }
    let windows = []
    if (amEnd > amStart) windows.push(...splitAroundBreaks(amStart, amEnd, breaks))
    if (pmStart != null && pmEnd != null && pmEnd > pmStart) windows.push(...splitAroundBreaks(pmStart, pmEnd, breaks))
    if (!windows.length) continue
    const onShiftHours = new Set()
    for (const w of windows) for (const h of hoursCovered(w.start, w.end)) onShiftHours.add(h)
    emps.push({ id: e.id, name: `${e.last_name}, ${e.first_name}`, trained, windows, otherCount: trained.length, onShiftHours })
  }

  // ---- demand matrix (no Meter fan-out in this team) ----
  const target = {} // jfId -> {hour -> headcount}
  for (const t of targets) {
    const hr = String(t.hour_start).slice(0, 5)
    ;(target[t.job_function_id] ??= {})[hr] = t.headcount
  }
  const covered = {} // jfId -> {hour -> count}
  for (const jf in target) { covered[jf] = {}; for (const h in target[jf]) covered[jf][h] = 0 }

  // --- per-function surplus controls (migration 010) + optional TEST overrides ---
  // Set SIM_TEST_CAPS=1 to exercise caps/overflow without touching DB config.
  const maxHeadcount = {}; const overflowFns = new Set()
  for (const jf of jobFunctions) {
    maxHeadcount[jf.id] = jf.max_headcount == null ? null : Number(jf.max_headcount)
    if (jf.surplus_overflow) overflowFns.add(jf.id)
  }
  if (process.env.SIM_TEST_CAPS) {
    const byName = (n) => jobFunctions.find((j) => j.name === n)?.id
    const capName = (n, v) => { const id = byName(n); if (id) maxHeadcount[id] = v }
    const ovName = (n) => { const id = byName(n); if (id) overflowFns.add(id) }
    capName('RT-pick', 5); capName('speedcell', 4); capName('Conveyor', 6); capName('Runner', 4); capName('DG Pick', 3)
    ovName('Pick'); ovName('Projects'); ovName('Locus')
    console.log('[TEST] caps: RT-pick=5 speedcell=4 Conveyor=6 Runner=4 DG Pick=3 | overflow: Pick, Projects, Locus')
  }
  const capRoom = (jfId, start, end) => {
    const cap = maxHeadcount[jfId]; if (cap == null) return true
    for (const h of hoursCovered(start, end)) if ((covered[jfId]?.[h] ?? 0) >= cap) return false
    return true
  }

  const assignments = [] // {empId, jfId, start, end}
  const empById = new Map(emps.map((e) => [e.id, e]))
  const distinctFns = new Map() // empId -> Set(jfId)
  const addAssign = (empId, jfId, start, end) => {
    assignments.push({ empId, jfId, start, end })
    for (const h of hoursCovered(start, end)) if (covered[jfId]?.[h] != null) covered[jfId][h]++
    if (!distinctFns.has(empId)) distinctFns.set(empId, new Set())
    distinctFns.get(empId).add(jfId)
    const e = empById.get(empId); e.windows = carve(e.windows, start, end)
  }
  const isTrained = (empId, jfId) => empById.get(empId)?.trained.includes(jfId)
  const canTake = (empId, jfId) => {
    const set = distinctFns.get(empId)
    if (!set || set.has(jfId) || set.size < MAX_FUNCTIONS) return true
    return false // at cap and new function (soft cap; scarce-gap override handled at call site)
  }

  // ---- STEP 1: required pins ----
  for (const e of emps) {
    const pref = prefBy[e.id]; if (!pref) continue
    const req = Object.values(pref).find((p) => p.is_required); if (!req) continue
    const amJf = req.am_job_function_id || req.job_function_id
    const pmJf = req.pm_job_function_id || req.job_function_id
    if (!isTrained(e.id, amJf)) continue
    for (const w of [...e.windows]) {
      const jf = w.start < 720 ? amJf : pmJf // before noon = AM
      if (isTrained(e.id, jf)) addAssign(e.id, jf, w.start, w.end)
    }
  }

  // ---- scarcity: trained supply / total demand (lower = scarcer) ----
  const trainedCount = {}; for (const t of training) trainedCount[t.job_function_id] = (trainedCount[t.job_function_id] || 0) + 1
  const totalDemand = {}; for (const jf in target) totalDemand[jf] = Object.values(target[jf]).reduce((a, b) => a + b, 0)
  const fnOrder = Object.keys(target).filter((jf) => totalDemand[jf] > 0)
    .sort((a, b) => ((trainedCount[a] || 0) / totalDemand[a]) - ((trainedCount[b] || 0) / totalDemand[b]))

  // unmet contiguous run for a function starting at/after some hour
  const firstUnmetRun = (jfId) => {
    const tgt = target[jfId], cov = covered[jfId], cap = maxHeadcount[jfId]
    const hrs = Object.keys(tgt).sort()
    let runStart = null, runEnd = null
    for (const h of hrs) {
      const c = cov[h]
      if (c < tgt[h] && (cap == null || c < cap)) { if (runStart == null) runStart = t2m(h); runEnd = t2m(h) + 60 }
      else if (runStart != null) break
    }
    return runStart == null ? null : { start: runStart, end: runEnd }
  }

  // ---- PASS 1: meet targets, scarce-first, sticky, long blocks ----
  for (const jfId of fnOrder) {
    let guard = 0
    while (guard++ < 500) {
      const run = firstUnmetRun(jfId); if (!run) break
      // candidate employees: trained, window overlapping run, respecting soft cap (or scarce override)
      let best = null
      for (const e of emps) {
        if (!isTrained(e.id, jfId)) continue
        const set = distinctFns.get(e.id)
        const atCapNew = set && !set.has(jfId) && set.size >= MAX_FUNCTIONS
        // scarce override: if very few trained, allow exceeding cap
        if (atCapNew && (trainedCount[jfId] || 0) > 6) continue
        for (const w of e.windows) {
          const s = Math.max(w.start, run.start), en = Math.min(w.end, run.end)
          if (en - s < MIN_BLOCK) continue
          if (!capRoom(jfId, s, en)) continue
          const sticky = set && set.has(jfId) ? 1 : 0
          const preferred = prefBy[e.id]?.[jfId] ? 1 : 0
          const score = (en - s) * 1 + sticky * 200 + preferred * 120 - e.otherCount * 3
          if (!best || score > best.score) best = { e, start: s, end: en, score }
        }
      }
      if (!best) break // genuine shortfall
      addAssign(best.e.id, jfId, best.start, best.end)
    }
  }

  // ---- PASS 2: surplus — assign all remaining availability, prefer continuity ----
  // staffing ratio per function for "most under-served" fallback
  const fnRatio = (jfId) => {
    const tgt = target[jfId]; if (!tgt) return Infinity
    let t = 0, c = 0; for (const h in tgt) { t += tgt[h]; c += covered[jfId]?.[h] || 0 }
    return t === 0 ? Infinity : c / t
  }
  let progress = true
  while (progress) {
    progress = false
    for (const e of emps) {
      if (!e.windows.length) continue
      const w = e.windows[0]
      if (w.end - w.start < MIN_BLOCK) { e.windows = e.windows.slice(1); continue }
      const set = distinctFns.get(e.id) || new Set()
      // candidate functions the employee is trained for, demand-bearing, with cap room
      let cand = e.trained.filter((jf) => target[jf] && capRoom(jf, w.start, w.end))
      if (set.size >= MAX_FUNCTIONS) cand = cand.filter((jf) => set.has(jf))
      if (!cand.length) cand = e.trained.filter((jf) => set.has(jf) && capRoom(jf, w.start, w.end)) // existing w/ room
      if (!cand.length) { e.windows = e.windows.slice(1); continue } // all capped → idle this window
      // meeting targets beats overflow sink: fill still-under-target functions first
      const underTargetAt = (jf) => { const tg = target[jf]; if (!tg) return false; for (const h of hoursCovered(w.start, w.end)) if ((covered[jf]?.[h] ?? 0) < (tg[h] ?? 0)) return true; return false }
      const under = cand.filter(underTargetAt)
      if (under.length) cand = under
      else { const ov = cand.filter((jf) => overflowFns.has(jf)); if (ov.length) cand = ov }
      // prefer: function adjacent to this window already assigned (continuity), else under-served, else existing
      let pick = null, pickScore = -Infinity
      for (const jf of cand) {
        const adjacent = assignments.some((a) => a.empId === e.id && a.jfId === jf && (a.end === w.start || a.start === w.end)) ? 1 : 0
        const existing = set.has(jf) ? 1 : 0
        const need = Math.max(0, 1 - fnRatio(jf)) // <1 means under target
        const score = adjacent * 100 + need * 40 + existing * 20 + (prefBy[e.id]?.[jf] ? 10 : 0)
        if (score > pickScore) { pickScore = score; pick = jf }
      }
      if (!pick) { e.windows = e.windows.slice(1); continue }
      addAssign(e.id, pick, w.start, w.end)
      progress = true
    }
  }

  // ---- PASS 3: merge adjacent same emp+function blocks ----
  const byEmp = new Map()
  for (const a of assignments) { if (!byEmp.has(a.empId)) byEmp.set(a.empId, []); byEmp.get(a.empId).push(a) }
  const merged = []
  for (const [empId, list] of byEmp) {
    list.sort((x, y) => x.start - y.start)
    let cur = null
    for (const a of list) {
      if (cur && cur.jfId === a.jfId && a.start <= cur.end) cur.end = Math.max(cur.end, a.end)
      else { if (cur) merged.push(cur); cur = { ...a } }
    }
    if (cur) merged.push(cur)
  }

  // ================= METRICS =================
  const metrics = (label, asg) => {
    const be = new Map()
    for (const a of asg) { if (!be.has(a.empId)) be.set(a.empId, []); be.get(a.empId).push(a) }
    let idle = 0; const fnDist = {}; const segDist = {}; let totalSegs = 0
    for (const e of emps) {
      const as = be.get(e.id) || []
      const span = origSpan.get(e.id) || 0
      let worked = 0; for (const a of as) worked += a.end - a.start
      idle += Math.max(0, span - worked)
      const nf = new Set(as.map((a) => a.jfId)).size
      fnDist[nf] = (fnDist[nf] || 0) + 1
      segDist[as.length] = (segDist[as.length] || 0) + 1
      totalSegs += as.length
    }
    // gaps + over
    let under = 0, over = 0, overCells = 0
    const cov2 = {}; const underByFn = {}; const overByFn = {}
    for (const jf in target) { cov2[jf] = {}; for (const h in target[jf]) cov2[jf][h] = 0 }
    for (const a of asg) for (const h of hoursCovered(a.start, a.end)) if (cov2[a.jfId]?.[h] != null) cov2[a.jfId][h]++
    for (const jf in target) for (const h in target[jf]) {
      const d = target[jf][h] - cov2[jf][h]
      if (d > 0) { under += d; underByFn[jfById.get(jf)?.name] = (underByFn[jfById.get(jf)?.name] || 0) + d }
      else if (d < 0) { over += -d; overCells++; overByFn[jfById.get(jf)?.name] = (overByFn[jfById.get(jf)?.name] || 0) + (-d) }
    }
    console.log(`\n===== ${label} =====`)
    console.log('assignments:', asg.length, '| total segments:', totalSegs, '| idle hrs:', (idle / 60).toFixed(1))
    console.log('distinct functions/person:', JSON.stringify(fnDist))
    console.log('segments/person:', JSON.stringify(segDist))
    console.log('UNMET headcount-hours (gaps):', under, '| OVER-target headcount-hours:', over, `(${overCells} cells)`)
    console.log('  unmet by function:', JSON.stringify(underByFn))
    console.log('  over-target by function:', JSON.stringify(overByFn))
  }
  const origSpan = new Map()
  for (const e of employees) {
    const s = shiftById.get(e.shift_id); if (!s) continue
    if (!empById.has(e.id)) continue
    const lunch = s.lunch_start && s.lunch_end ? t2m(s.lunch_end) - t2m(s.lunch_start) : 0
    origSpan.set(e.id, t2m(s.end_time) - t2m(s.start_time) - lunch)
  }

  // ---- FIXABLE-GAP detector: unmet (jf,hour) where a trained person is idle or on an over-target fn ----
  const finalCov = {}
  for (const jf in target) { finalCov[jf] = {}; for (const h in target[jf]) finalCov[jf][h] = 0 }
  for (const a of merged) for (const h of hoursCovered(a.start, a.end)) if (finalCov[a.jfId]?.[h] != null) finalCov[a.jfId][h]++
  const empHourFn = new Map() // `${empId}|${hour}` -> jfId
  for (const a of merged) for (const h of hoursCovered(a.start, a.end)) empHourFn.set(`${a.empId}|${h}`, a.jfId)
  let fixable = 0
  for (const jf in target) for (const h in target[jf]) {
    if (finalCov[jf][h] >= target[jf][h]) continue
    for (const e of emps) {
      if (!e.trained.includes(jf)) continue
      if (!e.onShiftHours.has(h)) continue // not at work that hour — genuine, not fixable
      const onFn = empHourFn.get(`${e.id}|${h}`)
      const idleNow = !onFn // on shift but unassigned that hour
      const onOver = onFn && onFn !== jf && finalCov[onFn]?.[h] > target[onFn]?.[h]
      if (idleNow || onOver) { fixable++; break }
    }
  }
  console.log(`Schedulable employees: ${emps.length} | date ${DATE}`)
  console.log(`FIXABLE gap-cells (trained person idle/over-parked while gap unmet): ${fixable}`)
  console.log('Scarce-first order:', fnOrder.map((j) => jfById.get(j)?.name).join(' → '))
  const oldAsg = dbAssigns.map((a) => ({ empId: a.employee_id, jfId: a.job_function_id, start: t2m(a.start_time), end: t2m(a.end_time) }))
  metrics('OLD ALGORITHM (actual DB output)', oldAsg)
  metrics('NEW ALGORITHM (merged)', merged)

  // show a few sample employees
  console.log('\n=== sample employee days (merged) ===')
  const sample = ['Smith, Barbara', 'Smith, Emily', 'Smith, Patricia', 'Smith, George', 'Smith, Karen']
  for (const nm of sample) {
    const e = emps.find((x) => x.name === nm); if (!e) continue
    const as = merged.filter((a) => a.empId === e.id).sort((x, y) => x.start - y.start)
    console.log(nm.padEnd(18), as.map((a) => `${jfById.get(a.jfId)?.name} ${m2t(a.start)}-${m2t(a.end)}`).join(' | ') || '(idle)')
  }
}
main().catch((e) => console.error('ERR', e.message, e.stack))
