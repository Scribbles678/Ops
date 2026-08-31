/**
 * Seed mock PTO / request data so the PTO Calendar has something to look at.
 *
 *   node scripts/seed-pto-mock.mjs                      # this week + next week
 *   node scripts/seed-pto-mock.mjs --week 2026-08-24    # anchor on a specific Monday
 *   node scripts/seed-pto-mock.mjs --team "Site B"
 *   node scripts/seed-pto-mock.mjs --clear              # remove everything it created
 *
 * LOCAL DEV ONLY. Every row it writes is tagged "[mock]" in its notes/reason, and
 * --clear deletes exactly those rows and nothing else, so this can never eat real
 * data. It is not part of the app and does not ship in the image (the Dockerfile
 * copies only .output and sql-schema).
 *
 * It mirrors what the real approval engine does rather than inventing its own
 * shape: an approved absence gets BOTH a schedule_requests row and the pto_days
 * row it created, linked by created_pto_id. The calendar dedupes on that link, so
 * a request written without it shows the person twice.
 *
 * NOTHING HERE IS 'pending', deliberately. The rule engine decides every request
 * inside the submit transaction and writes 'approved' or 'rejected'; the column
 * defaults to 'pending' but no code path leaves a row there. Seeding pending rows
 * produced a "Pending Requests" panel that cannot exist in production, which is
 * misleading rather than useful. An admin reverses a decision from the Requests
 * table instead.
 *
 * pto_days storage conventions (see docs/PTO-AND-REQUESTS.md - two of the four
 * types are NOT what you would guess):
 *   full_day     start NULL          end NULL
 *   partial      start               end
 *   leave_early  start = they LEAVE  end NULL
 *   arrive_late  start '00:00:00'    end = they ARRIVE
 *   call_in      start NULL          end NULL
 */
import pkg from 'pg'

const { Client } = pkg
const MARK = '[mock]'

const argv = process.argv.slice(2)
const flag = (name, fallback = null) => {
  const i = argv.indexOf('--' + name)
  return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : fallback
}
const CLEAR = argv.includes('--clear')
const TEAM_NAME = flag('team')
const CONN = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5433/scheduling'

const pad = (n) => String(n).padStart(2, '0')
const fmt = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`

/** Monday of the week containing `d`. */
const mondayOf = (d) => {
  const out = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  const dow = out.getDay() // 0 Sun .. 6 Sat
  out.setDate(out.getDate() + (dow === 0 ? -6 : 1 - dow))
  return out
}

const anchorArg = flag('week')
const anchor = anchorArg ? mondayOf(new Date(anchorArg + 'T00:00:00')) : mondayOf(new Date())
/** Day N counting from the anchor Monday (0 = Mon of week 1, 7 = Mon of week 2). */
const day = (n) => {
  const d = new Date(anchor)
  d.setDate(d.getDate() + n)
  return fmt(d)
}

const c = new Client({ connectionString: CONN })
await c.connect()

const teams = (await c.query('select id, name from teams order by created_at asc')).rows
if (!teams.length) throw new Error('No teams in the database.')
const team = TEAM_NAME ? teams.find((t) => t.name === TEAM_NAME) : teams[0]
if (!team) throw new Error(`Team "${TEAM_NAME}" not found. Have: ${teams.map((t) => t.name).join(', ')}`)

// ---------------------------------------------------------------------------
// --clear: remove only what this script wrote
// ---------------------------------------------------------------------------
if (CLEAR) {
  // Requests first: they reference pto_days via created_pto_id.
  const r = await c.query(`DELETE FROM schedule_requests WHERE team_id = $1 AND notes LIKE $2`, [team.id, `%${MARK}%`])
  const p = await c.query(`DELETE FROM pto_days WHERE team_id = $1 AND notes LIKE $2`, [team.id, `%${MARK}%`])
  const s = await c.query(`DELETE FROM shift_swaps WHERE team_id = $1 AND notes LIKE $2`, [team.id, `%${MARK}%`])
  const b = await c.query(`DELETE FROM team_blocked_dates WHERE team_id = $1 AND reason LIKE $2`, [team.id, `%${MARK}%`])
  console.log(
    `cleared mock data from "${team.name}": ` +
    `${r.rowCount} request(s), ${p.rowCount} pto day(s), ${s.rowCount} swap(s), ${b.rowCount} blocked date(s)`
  )
  await c.end()
  process.exit(0)
}

const employees = (
  await c.query(
    `select id, first_name, last_name from employees
     where team_id = $1 and is_active is not false and shift_id is not null
     order by last_name, first_name`,
    [team.id]
  )
).rows
if (employees.length < 6) throw new Error(`Team "${team.name}" has only ${employees.length} schedulable employees; need at least 6.`)

const shifts = (await c.query('select id, name from shifts where team_id = $1 order by start_time', [team.id])).rows

const emp = (i) => employees[i % employees.length]
const name = (e) => `${e.first_name} ${e.last_name}`

// ---------------------------------------------------------------------------
// helpers that write the same shape the real approval engine writes
// ---------------------------------------------------------------------------
const note = (text) => `${text} ${MARK}`

/** Approved absence: pto_days row + the request that created it, linked. */
async function approvedAbsence({ employee, date, requestType, ptoType, ptoStart, ptoEnd, reqStart, reqEnd, text }) {
  const pto = await c.query(
    `INSERT INTO pto_days (employee_id, pto_date, start_time, end_time, pto_type, notes, team_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    [employee.id, date, ptoStart, ptoEnd, ptoType, note(text), team.id]
  )
  await c.query(
    `INSERT INTO schedule_requests
       (employee_id, team_id, request_type, status, request_date, start_time, end_time,
        approval_rule_results, notes, created_pto_id)
     VALUES ($1,$2,$3,'approved',$4,$5,$6,'{}'::jsonb,$7,$8)`,
    [employee.id, team.id, requestType, date, reqStart, reqEnd, note(text), pto.rows[0].id]
  )
}

/** A manual pto_days row with no originating request - a call-in. */
async function manualPto({ employee, date, ptoType, text }) {
  await c.query(
    `INSERT INTO pto_days (employee_id, pto_date, pto_type, notes, team_id)
     VALUES ($1,$2,$3,$4,$5)`,
    [employee.id, date, ptoType, note(text), team.id]
  )
}

/** A request the rules refused, with the reason the engine would have written. */
async function rejectedRequest({ employee, date, requestType, start, end, text, rejection }) {
  await c.query(
    `INSERT INTO schedule_requests
       (employee_id, team_id, request_type, status, request_date, start_time, end_time,
        approval_rule_results, rejection_reason, notes)
     VALUES ($1,$2,$3,'rejected',$4,$5,$6,'{}'::jsonb,$7,$8)`,
    [employee.id, team.id, requestType, date, start, end, rejection, note(text)]
  )
}

/** An approved shift swap: the request plus the shift_swaps row it materializes. */
async function approvedSwap({ employee, date, origShift, reqShift, text }) {
  const swap = await c.query(
    `INSERT INTO shift_swaps (employee_id, swap_date, original_shift_id, swapped_shift_id, notes, team_id)
     VALUES ($1,$2,$3,$4,$5,$6)
     ON CONFLICT (employee_id, swap_date) DO UPDATE SET swapped_shift_id = EXCLUDED.swapped_shift_id
     RETURNING id`,
    [employee.id, date, origShift, reqShift, note(text), team.id]
  )
  await c.query(
    `INSERT INTO schedule_requests
       (employee_id, team_id, request_type, status, request_date,
        original_shift_id, requested_shift_id, approval_rule_results, notes, created_swap_id)
     VALUES ($1,$2,'shift_swap','approved',$3,$4,$5,'{}'::jsonb,$6,$7)`,
    [employee.id, team.id, date, origShift, reqShift, note(text), swap.rows[0].id]
  )
}

// ---------------------------------------------------------------------------
// the data - a realistic spread across two weeks, covering every render path
// ---------------------------------------------------------------------------
const created = []

// --- week 1 -----------------------------------------------------------------
await approvedAbsence({ employee: emp(0), date: day(0), requestType: 'pto_full_day', ptoType: 'full_day',
  ptoStart: null, ptoEnd: null, reqStart: null, reqEnd: null, text: 'Vacation' })
created.push(`${day(0)}  ${name(emp(0))}  full day`)

await approvedAbsence({ employee: emp(1), date: day(0), requestType: 'leave_early', ptoType: 'leave_early',
  ptoStart: '14:00:00', ptoEnd: null, reqStart: '14:00:00', reqEnd: null, text: 'Appointment' })
created.push(`${day(0)}  ${name(emp(1))}  leaves 2:00 PM`)

await approvedAbsence({ employee: emp(2), date: day(1), requestType: 'pto_partial', ptoType: 'partial',
  ptoStart: '08:00:00', ptoEnd: '12:00:00', reqStart: '08:00:00', reqEnd: '12:00:00', text: 'Half day' })
created.push(`${day(1)}  ${name(emp(2))}  8:00 AM - 12:00 PM`)

await approvedAbsence({ employee: emp(3), date: day(1), requestType: 'arrive_late', ptoType: 'arrive_late',
  ptoStart: '00:00:00', ptoEnd: '10:00:00', reqStart: '10:00:00', reqEnd: null, text: 'School run' })
created.push(`${day(1)}  ${name(emp(3))}  arrives 10:00 AM`)

await manualPto({ employee: emp(4), date: day(2), ptoType: 'call_in', text: 'Called in sick' })
created.push(`${day(2)}  ${name(emp(4))}  call-in (no request)`)

await approvedAbsence({ employee: emp(5), date: day(2), requestType: 'pto_full_day', ptoType: 'full_day',
  ptoStart: null, ptoEnd: null, reqStart: null, reqEnd: null, text: 'Vacation' })
created.push(`${day(2)}  ${name(emp(5))}  full day`)

// A heavier day, so the cell has to stack several entries.
for (const i of [6, 7, 8]) {
  await approvedAbsence({ employee: emp(i), date: day(3), requestType: 'pto_full_day', ptoType: 'full_day',
    ptoStart: null, ptoEnd: null, reqStart: null, reqEnd: null, text: 'Vacation' })
  created.push(`${day(3)}  ${name(emp(i))}  full day`)
}
await approvedAbsence({ employee: emp(9), date: day(3), requestType: 'leave_early', ptoType: 'leave_early',
  ptoStart: '15:30:00', ptoEnd: null, reqStart: '15:30:00', reqEnd: null, text: 'Family' })
created.push(`${day(3)}  ${name(emp(9))}  leaves 3:30 PM`)

await approvedAbsence({ employee: emp(10), date: day(4), requestType: 'pto_partial', ptoType: 'partial',
  ptoStart: '13:00:00', ptoEnd: '16:30:00', reqStart: '13:00:00', reqEnd: '16:30:00', text: 'Afternoon off' })
created.push(`${day(4)}  ${name(emp(10))}  1:00 PM - 4:30 PM`)

await rejectedRequest({ employee: emp(11), date: day(4), requestType: 'pto_full_day',
  start: null, end: null, text: 'Over the day limit',
  rejection: 'Team PTO hours limit for the day exceeded (8h of 8h used, this needs 8h)' })
created.push(`${day(4)}  ${name(emp(11))}  full day  REJECTED (day limit)`)

// --- week 2 -----------------------------------------------------------------
await approvedAbsence({ employee: emp(12), date: day(7), requestType: 'pto_full_day', ptoType: 'full_day',
  ptoStart: null, ptoEnd: null, reqStart: null, reqEnd: null, text: 'Vacation' })
created.push(`${day(7)}  ${name(emp(12))}  full day`)

await rejectedRequest({ employee: emp(13), date: day(7), requestType: 'pto_full_day',
  start: null, end: null, text: 'Too short notice',
  rejection: 'Requests must be made at least 1 business day(s) in advance' })
created.push(`${day(7)}  ${name(emp(13))}  full day  REJECTED (notice)`)

await approvedAbsence({ employee: emp(14), date: day(8), requestType: 'arrive_late', ptoType: 'arrive_late',
  ptoStart: '00:00:00', ptoEnd: '09:30:00', reqStart: '09:30:00', reqEnd: null, text: 'Late start' })
created.push(`${day(8)}  ${name(emp(14))}  arrives 9:30 AM`)

await approvedAbsence({ employee: emp(15), date: day(9), requestType: 'leave_early', ptoType: 'leave_early',
  ptoStart: '16:00:00', ptoEnd: null, reqStart: '16:00:00', reqEnd: null, text: 'Appointment' })
created.push(`${day(9)}  ${name(emp(15))}  leaves 4:00 PM`)

if (shifts.length >= 2) {
  await approvedSwap({ employee: emp(16), date: day(9),
    origShift: shifts[0].id, reqShift: shifts[1].id,
    text: `Swap ${shifts[0].name} to ${shifts[1].name}` })
  created.push(`${day(9)}  ${name(emp(16))}  shift swap  approved`)
}

// A blocked date plus a request that was refused because of it.
await c.query(
  `INSERT INTO team_blocked_dates (team_id, blocked_date, reason)
   VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
  [team.id, day(10), note('Month-end close')]
)
created.push(`${day(10)} BLOCKED - month-end close`)

await rejectedRequest({ employee: emp(17), date: day(10), requestType: 'pto_full_day',
  start: null, end: null, text: 'Refused - blocked date',
  rejection: 'Requests not allowed on this date: Month-end close' })
created.push(`${day(10)} ${name(emp(17))}  full day  REJECTED`)

await approvedAbsence({ employee: emp(18), date: day(11), requestType: 'pto_partial', ptoType: 'partial',
  ptoStart: '07:00:00', ptoEnd: '11:00:00', reqStart: '07:00:00', reqEnd: '11:00:00', text: 'Morning off' })
created.push(`${day(11)} ${name(emp(18))}  7:00 AM - 11:00 AM`)

await c.end()

console.log(`seeded mock PTO for team "${team.name}", weeks of ${day(0)} and ${day(7)}:\n`)
for (const line of created) console.log('  ' + line)
console.log(`\n${created.length} item(s). Remove them with:  node scripts/seed-pto-mock.mjs --clear`)
