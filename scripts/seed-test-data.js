/**
 * Seed test data: job functions, shifts, employees, training, targets, sample schedule.
 * Run after seed-first-user.js. Uses Default Team.
 *
 * Matches the distribution center setup from the app's mock data:
 * - Job Function Dashboards: Meter, Locus, Pick, X4, EM9, Speedcell, Helpdesk
 * - Shifts: X4 (day), EM9 (swing), Locus (overnight)
 * - 50 employees, each trained on Locus, Pick, Meter, X4, EM9
 *
 * Usage:
 *   node scripts/seed-test-data.js           # Add test data (skips if already exists)
 *   node scripts/seed-test-data.js --reset   # Clear test data and re-seed
 *
 * Requires: DATABASE_URL (default: postgresql://postgres:postgres@localhost:5432/scheduling)
 */

import pg from 'pg'

const DATABASE_URL =
  process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/scheduling'

// Job functions - Locus, Pick, X4, EM9, Meter (each meter is the same; schedule assigns to specific meter)
const JOB_FUNCTIONS = [
  { name: 'Locus', color: '#FFD700', rate: 30, unit: 'orders/hour', sort: 0 },
  { name: 'Pick', color: '#FFFF00', rate: 55, unit: 'cartons/hour', sort: 1 },
  { name: 'X4', color: '#3B82F6', rate: 50, unit: 'cases/hour', sort: 2 },
  { name: 'EM9', color: '#10B981', rate: 45, unit: 'units/hour', sort: 3 },
  { name: 'Meter', color: '#87CEEB', rate: 50, unit: 'cases/hour', sort: 4 },
]

// Shifts - X4 (day), EM9 (swing), Locus (overnight)
const SHIFTS = [
  { name: 'X4', start: '06:00', end: '14:30', lunch: '10:00-10:30' },
  { name: 'EM9', start: '14:00', end: '22:30', lunch: '18:00-18:30' },
  { name: 'Locus', start: '22:00', end: '06:30', lunch: '02:00-02:30' },
]

// Common first/last names for generating 50 employees
const FIRST_NAMES = ['James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Linda', 'William', 'Elizabeth', 'David', 'Barbara', 'Richard', 'Susan', 'Joseph', 'Jessica', 'Thomas', 'Sarah', 'Charles', 'Karen', 'Christopher', 'Lisa', 'Daniel', 'Nancy', 'Matthew', 'Betty', 'Anthony', 'Margaret', 'Mark', 'Sandra', 'Donald', 'Ashley', 'Steven', 'Kimberly', 'Paul', 'Emily', 'Andrew', 'Donna', 'Joshua', 'Michelle', 'Kenneth', 'Carol', 'Kevin', 'Amanda', 'Brian', 'Dorothy', 'George', 'Melissa', 'Timothy', 'Deborah']
const LAST_NAMES = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark', 'Ramirez', 'Lewis', 'Robinson', 'Walker', 'Young', 'Allen', 'King', 'Wright', 'Scott', 'Torres', 'Nguyen', 'Hill', 'Flores', 'Green', 'Adams', 'Nelson', 'Baker', 'Hall', 'Rivera', 'Campbell', 'Mitchell', 'Carter', 'Roberts']

// 50 employees - each trained on Locus, Pick, Meter, X4, EM9 (you can edit after seeding)
const TRAINED_JOBS = ['Locus', 'Pick', 'Meter', 'X4', 'EM9']

function generateEmployees(n) {
  const seen = new Set()
  const out = []
  let i = 0
  while (out.length < n) {
    const first = FIRST_NAMES[i % FIRST_NAMES.length]
    const last = LAST_NAMES[Math.floor(i / FIRST_NAMES.length) % LAST_NAMES.length]
    const key = `${first} ${last}`
    if (!seen.has(key)) {
      seen.add(key)
      out.push({ first, last })
    }
    i++
  }
  return out
}

const EMPLOYEES = generateEmployees(50)

async function main() {
  const reset = process.argv.includes('--reset')

  const client = new pg.Client({
    connectionString: DATABASE_URL,
    ssl: process.env.DATABASE_SSL === 'false' || DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false },
  })

  await client.connect()

  try {
    const teamRes = await client.query(`SELECT id FROM teams WHERE name = 'Default Team' LIMIT 1`)
    const teamId = teamRes.rows[0]?.id
    if (!teamId) {
      console.log('No Default Team found. Run seed-first-user.js first.')
      process.exit(1)
    }

    if (reset) {
      console.log('Resetting test data...')
      await client.query('DELETE FROM schedule_assignments WHERE team_id = $1', [teamId])
      await client.query('DELETE FROM daily_targets WHERE team_id = $1', [teamId])
      await client.query('DELETE FROM employee_training WHERE team_id = $1', [teamId])
      await client.query('DELETE FROM employees WHERE team_id = $1', [teamId])
      await client.query('DELETE FROM shifts WHERE team_id = $1', [teamId])
      await client.query('DELETE FROM job_functions WHERE team_id = $1', [teamId])
      await client.query('DELETE FROM target_hours WHERE team_id = $1', [teamId])
      console.log('Cleared.')
    }

    const existingJf = await client.query('SELECT 1 FROM job_functions WHERE team_id = $1 LIMIT 1', [teamId])
    if (existingJf.rows.length > 0 && !reset) {
      console.log('Test data already exists. Use --reset to clear and re-seed.')
      return
    }

    console.log('Seeding job functions...')
    const jobFunctionIds = {}
    for (let i = 0; i < JOB_FUNCTIONS.length; i++) {
      const jf = JOB_FUNCTIONS[i]
      const res = await client.query(
        `INSERT INTO job_functions (name, color_code, productivity_rate, unit_of_measure, sort_order, team_id)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (name, team_id) DO UPDATE SET color_code = EXCLUDED.color_code
         RETURNING id, name`,
        [jf.name, jf.color, jf.rate, jf.unit, i, teamId]
      )
      jobFunctionIds[jf.name] = res.rows[0].id
    }

    console.log('Seeding shifts...')
    const shiftIds = []
    for (const sh of SHIFTS) {
      const [lunchStart, lunchEnd] = sh.lunch ? sh.lunch.split('-') : [null, null]
      const res = await client.query(
        `INSERT INTO shifts (name, start_time, end_time, lunch_start, lunch_end, team_id)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, name`,
        [sh.name, sh.start, sh.end, lunchStart, lunchEnd, teamId]
      )
      shiftIds.push({ id: res.rows[0].id, name: sh.name })
    }

    console.log('Seeding employees...')
    const employeeIds = []
    const shiftByName = Object.fromEntries(shiftIds.map(s => [s.name, s.id]))
    for (let i = 0; i < EMPLOYEES.length; i++) {
      const emp = EMPLOYEES[i]
      const shiftName = SHIFTS[i % SHIFTS.length].name
      const shiftId = shiftByName[shiftName]
      const res = await client.query(
        `INSERT INTO employees (first_name, last_name, shift_id, team_id)
         VALUES ($1, $2, $3, $4)
         RETURNING id, first_name, last_name`,
        [emp.first, emp.last, shiftId, teamId]
      )
      employeeIds.push({ id: res.rows[0].id, first: emp.first, last: emp.last })
    }

    console.log('Seeding employee training (Locus, Pick, Meter, X4, EM9 for each)...')
    for (const emp of employeeIds) {
      for (const jfName of TRAINED_JOBS) {
        const jfId = jobFunctionIds[jfName]
        if (!jfId) continue
        await client.query(
          `INSERT INTO employee_training (employee_id, job_function_id, team_id)
           VALUES ($1, $2, $3)
           ON CONFLICT (employee_id, job_function_id) DO NOTHING`,
          [emp.id, jfId, teamId]
        )
      }
    }

    console.log('Seeding target hours...')
    for (const [name, jfId] of Object.entries(jobFunctionIds)) {
      await client.query(
        `INSERT INTO target_hours (job_function_id, target_hours, team_id)
         VALUES ($1, 8, $2)
         ON CONFLICT (job_function_id, team_id) DO UPDATE SET target_hours = 8`,
        [jfId, teamId]
      )
    }

    const today = new Date().toISOString().split('T')[0]
    console.log('Seeding daily targets for today...')
    for (const jfId of Object.values(jobFunctionIds)) {
      await client.query(
        `INSERT INTO daily_targets (schedule_date, job_function_id, target_units, team_id)
         VALUES ($1, $2, 8, $3)
         ON CONFLICT (schedule_date, job_function_id, team_id) DO UPDATE SET target_units = 8`,
        [today, jfId, teamId]
      )
    }

    console.log('\n✅ Test data seeded successfully!\n')
    console.log('  Job functions:', JOB_FUNCTIONS.length)
    console.log('  Shifts:', SHIFTS.length)
    console.log('  Employees:', EMPLOYEES.length)
    console.log('  Target hours & daily targets set to 8\n')
    console.log('  Log in at http://localhost:3000 and try the app.\n')
  } catch (err) {
    console.error(err)
    process.exit(1)
  } finally {
    await client.end()
  }
}

main()
