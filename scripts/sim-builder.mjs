/**
 * Headless harness: replay REAL database inputs through the REAL builder engine
 * and print quality metrics. Read-only - it never writes to the database.
 *
 *   node scripts/sim-builder.mjs 2026-08-03
 *   node scripts/sim-builder.mjs 2026-08-03 --team "Site B"
 *
 * WHY IT LOOKS LIKE THIS: this file used to contain a hand-written second copy of
 * the builder algorithm. It drifted, so engine changes were judged against code
 * that was never shipped. It now bundles the real source with esbuild and calls
 * it, and holds NO scheduling logic of its own - only loading and reporting.
 *
 * Availability, demand and Meter fan-out come from the engine's own prepare(), so
 * the scoreboard cannot disagree with the engine about who was actually free.
 *
 * Reads ONE team, matching how the app scopes a build. Reading every team at once
 * is the bug that was fixed in Aug 2026, not a feature to keep here.
 */
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import pkg from 'pg'
import * as esbuild from 'esbuild'

const { Client } = pkg
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const SLOTS = 96
const SLOT_MIN = 15

const argv = process.argv.slice(2)
const flag = (name, fallback = null) => {
  const i = argv.indexOf('--' + name)
  return i >= 0 && argv[i + 1] ? argv[i + 1] : fallback
}
const DATE = argv.find((a) => /^\d{4}-\d{2}-\d{2}$/.test(a)) || new Date().toISOString().slice(0, 10)
const TEAM_NAME = flag('team')
const CONN = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5433/scheduling'

/** Bundle the real engine sources and import them. No copies, no drift. */
async function loadEngines() {
  const out = await esbuild.build({
    stdin: {
      contents: [
        "export { prepare } from './utils/scheduleEngineV2/prepare'",
        "export { runEngine } from './utils/scheduleEngineV2/engine'",
      ].join('\n'),
      resolveDir: ROOT,
      loader: 'ts',
    },
    bundle: true,
    format: 'esm',
    platform: 'node',
    write: false,
    logLevel: 'silent',
  })
  const code = out.outputFiles[0].text
  return import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'))
}

/** Load one team's rows, the same set the team-scoped APIs would return. */
async function loadInputs() {
  const c = new Client({ connectionString: CONN })
  await c.connect()
  const teams = (await c.query('select id, name from teams order by created_at asc')).rows
  if (!teams.length) throw new Error('No teams in the database.')
  const team = TEAM_NAME ? teams.find((t) => t.name === TEAM_NAME) : teams[0]
  if (!team) throw new Error('Team "' + TEAM_NAME + '" not found. Have: ' + teams.map((t) => t.name).join(', '))

  const q = async (sql, params = []) => (await c.query(sql, params)).rows
  const T = [team.id]

  const employees = await q('select * from employees where is_active is not false and team_id = $1', T)
  const shifts = await q('select * from shifts where team_id = $1', T)
  const jobFunctions = await q('select * from job_functions where team_id = $1', T)
  const trainingRows = await q('select employee_id, job_function_id from employee_training where team_id = $1', T)
  const targets = await q(
    'select job_function_id, hour_start, headcount from staffing_targets where is_active is not false and team_id = $1',
    T
  )
  const prefs = await q(
    "select pa.*, coalesce((select json_agg(json_build_object('id', b.id, 'start_time', b.start_time, 'end_time', b.end_time, 'job_function_id', b.job_function_id) order by b.start_time) from preferred_assignment_blocks b where b.preferred_assignment_id = pa.id), '[]'::json) as blocks from preferred_assignments pa where pa.team_id = $1",
    T
  )
  const pto = await q('select * from pto_days where pto_date = $1 and team_id = $2', [DATE, team.id])
  // Swaps replace an employee's shift for the date. The app honours them, so the
  // harness must too — a harness that models availability differently from the
  // engine is exactly the drift this file was rewritten to remove.
  const swaps = await q(
    'select employee_id, swapped_shift_id from shift_swaps where swap_date = $1 and team_id = $2',
    [DATE, team.id]
  )
  await c.end()

  const training = {}
  for (const r of trainingRows) (training[r.employee_id] ??= []).push(r.job_function_id)
  const prefMap = {}
  for (const pa of prefs) (prefMap[pa.employee_id] ??= {})[pa.job_function_id] = pa
  const ptoByEmployee = {}
  for (const p of pto) (ptoByEmployee[p.employee_id] ??= []).push(p)
  const swappedShiftByEmployee = {}
  for (const sw of swaps) {
    if (sw.employee_id && sw.swapped_shift_id) swappedShiftByEmployee[sw.employee_id] = sw.swapped_shift_id
  }

  return { team, employees, shifts, jobFunctions, targets, training, prefMap, ptoByEmployee, pto, swappedShiftByEmployee, swaps }
}

const hrs = (slots) => (slots / 4).toFixed(1)
const slotT = (s) => `${String(Math.floor(s / 4)).padStart(2, '0')}:${String((s % 4) * SLOT_MIN).padStart(2, '0')}`

/**
 * The harness's only real job: turn a set of assignments into quality numbers.
 * `prepared` must be a FRESH prepare() result - the engines mutate their own.
 */
function score(label, assignments, prepared) {
  const covered = new Map(prepared.functions.map((f) => [f.id, new Int16Array(SLOTS)]))
  const busy = new Map(prepared.employees.map((e) => [e.id, new Uint8Array(SLOTS)]))
  const fnsByEmp = new Map()
  const byEmp = new Map()
  let assignedSlots = 0

  for (const a of assignments) {
    const cov = covered.get(a.functionId)
    const bz = busy.get(a.employeeId)
    if (!cov || !bz) continue
    for (let s = a.startSlot; s < a.endSlot; s++) {
      cov[s]++
      if (!bz[s]) {
        bz[s] = 1
        assignedSlots++
      }
    }
    if (!fnsByEmp.has(a.employeeId)) fnsByEmp.set(a.employeeId, new Set())
    fnsByEmp.get(a.employeeId).add(a.functionId)
    if (!byEmp.has(a.employeeId)) byEmp.set(a.employeeId, [])
    byEmp.get(a.employeeId).push(a)
  }

  let onClock = 0
  let noWork = 0
  const fnDist = {}
  // Bouncing: a PERIOD is a maximal on-clock run between breaks/lunch/PTO (the
  // free grid straight out of prepare()). Count the periods that carry more than
  // one function - the team lead's complaint about people moved between jobs.
  let periods = 0
  let switchedPeriods = 0
  let peopleWhoSwitch = 0
  const examples = []
  for (const e of prepared.employees) {
    onClock += e.onClockSlots
    const n = fnsByEmp.get(e.id) ? fnsByEmp.get(e.id).size : 0
    fnDist[n] = (fnDist[n] ?? 0) + 1
    if (n === 0 && e.onClockSlots > 0) noWork++

    let runStart = -1
    let switched = false
    for (let s = 0; s <= SLOTS; s++) {
      const free = s < SLOTS && e.free[s] === 1
      if (free && runStart < 0) runStart = s
      if (!free && runStart >= 0) {
        periods++
        const inRun = (byEmp.get(e.id) ?? []).filter((a) => a.startSlot < s && a.endSlot > runStart).sort((x, y) => x.startSlot - y.startSlot)
        if (new Set(inRun.map((a) => a.functionId)).size > 1) {
          switchedPeriods++
          switched = true
          if (examples.length < 5) {
            const fnName = (id) => prepared.functions.find((f) => f.id === id)?.name ?? '?'
            examples.push(`${e.name} ${slotT(runStart)}-${slotT(s)}: ${inRun.map((a) => `${fnName(a.functionId)} ${slotT(a.startSlot)}-${slotT(a.endSlot)}`).join(' > ')}`)
          }
        }
        runStart = -1
      }
    }
    if (switched) peopleWhoSwitch++
  }

  let unmet = 0
  let over = 0
  let fixable = 0
  let notCounted = 0
  const unmetByFn = {}
  const overByFn = {}
  for (const fn of prepared.functions) {
    const cov = covered.get(fn.id)
    for (let s = 0; s < SLOTS; s++) {
      const need = fn.demand[s] ?? 0
      const have = cov[s] ?? 0
      if (have < need) {
        const short = need - have
        // A hole during a break or lunch is not a gap, by the floor's own rule
        // (EngineFunction.mustCover).
        if (fn.mustCover[s] !== 1) { notCounted += short; continue }
        unmet += short
        unmetByFn[fn.name] = (unmetByFn[fn.name] ?? 0) + short
        // Fixable: somebody trained for this function was free and unassigned at
        // this very slot. That is the builder's own miss, not a short floor.
        for (const e of prepared.employees) {
          if (!e.trained.has(fn.id)) continue
          if (e.free[s] === 1 && busy.get(e.id)[s] === 0) {
            fixable += short
            break
          }
        }
      } else if (need > 0 && have > need) {
        over += have - need
        overByFn[fn.name] = (overByFn[fn.name] ?? 0) + (have - need)
      }
    }
  }

  const top = (obj) =>
    Object.entries(obj)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(([k, v]) => k + ' ' + hrs(v) + 'h')
      .join(', ') || '(none)'

  console.log('\n===== ' + label + ' =====')
  console.log(
    'assignments: ' + assignments.length +
    ' | on-clock ' + hrs(onClock) + 'h' +
    ' | assigned ' + hrs(assignedSlots) + 'h' +
    ' | IDLE ' + hrs(onClock - assignedSlots) + 'h'
  )
  console.log('distinct functions/person: ' + JSON.stringify(fnDist) + ' | employees with no work: ' + noWork)
  console.log('UNMET ' + hrs(unmet) + 'h  |  OVER-target ' + hrs(over) + 'h  |  break/lunch holes not counted: ' + hrs(notCounted) + 'h')
  console.log('  unmet by function: ' + top(unmetByFn))
  console.log('  over by function:  ' + top(overByFn))
  console.log("FIXABLE unmet (a trained person was free and idle): " + hrs(fixable) + "h  <-- the engine's own misses")
  console.log('BOUNCING: ' + switchedPeriods + ' of ' + periods + ' stretches between breaks carry more than one function | people who switch mid-stretch: ' + peopleWhoSwitch)
  for (const x of examples) console.log('    e.g. ' + x)
}

const { prepare, runEngine } = await loadEngines()
const input = await loadInputs()

const prepArgs = () => ({
  employees: input.employees,
  jobFunctions: input.jobFunctions,
  shifts: input.shifts,
  training: input.training,
  staffingTargets: input.targets,
  preferredAssignments: input.prefMap,
  ptoByEmployee: input.ptoByEmployee,
  swappedShiftByEmployee: input.swappedShiftByEmployee,
})

console.log(
  'date ' + DATE + ' | team "' + input.team.name + '" | ' +
  input.employees.length + ' active employees, ' +
  input.jobFunctions.length + ' job functions, ' +
  input.targets.length + ' target rows, ' +
  input.pto.length + ' PTO rows, ' +
  input.swaps.length + ' shift swap(s)'
)

const prepared = prepare(prepArgs())
const result = runEngine({
  employees: prepared.employees,
  functions: prepared.functions,
  preferred: prepared.preferred,
  requiredPins: prepared.requiredPins,
})
score('Automated Schedule Builder', result.assignments, prepare(prepArgs()))
console.log(
  '  gaps: ' + result.gaps.length +
  ' | feasibility issues: ' + result.feasibility.length +
  ' | things to fix: ' + (prepared.actions.length + result.actions.length) +
  ' | notes: ' + (prepared.warnings.length + result.warnings.length)
)
for (const a of [...prepared.actions, ...result.actions]) console.log('    FIX: ' + a.message + (a.fix ? '  [' + a.fix + ']' : ''))
