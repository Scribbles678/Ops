/**
 * Browser smoke test: drive the real UI, capture screenshots, and fail on any
 * JavaScript error. This is the tier that `npm run build` cannot reach - a build
 * happily compiles a page that renders a red "could not be generated" banner over
 * a schedule that generated perfectly (a real bug, found exactly this way).
 *
 *   node scripts/ui-smoke.mjs
 *   node scripts/ui-smoke.mjs --base http://localhost:3000 --date 2026-09-01
 *   node scripts/ui-smoke.mjs --build        # also RUNS the builder (writes rows!)
 *
 * Screenshots land in scripts/.smoke/ (gitignored). Look at them - the whole point
 * is seeing what the supervisor sees.
 *
 * Requires playwright-core, deliberately NOT a package.json dependency: it is a
 * local dev tool and has no business slowing the production image build.
 *   npm i --no-save playwright-core
 *
 * Drives an already-installed Edge or Chrome, so no browser download is needed.
 */
import { existsSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

let chromium
try {
  ;({ chromium } = await import('playwright-core'))
} catch {
  console.error('playwright-core is not installed. Run:\n  npm i --no-save playwright-core')
  process.exit(1)
}

const HERE = dirname(fileURLToPath(import.meta.url))
const SHOTS = resolve(HERE, '.smoke')

const argv = process.argv.slice(2)
const flag = (name, fallback = null) => {
  const i = argv.indexOf('--' + name)
  return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : fallback
}
const has = (name) => argv.includes('--' + name)

const BASE = flag('base', 'http://localhost:3000')
const EMAIL = flag('email', 'admin@example.com')
const PASSWORD = flag('password', 'admin123')
const DATE = flag('date', new Date(Date.now() + 86400000).toISOString().slice(0, 10))
const BUILD = has('build')

const BROWSERS = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
]
const executablePath = BROWSERS.find((p) => existsSync(p))
if (!executablePath) {
  console.error('No installed Edge/Chrome found. Add its path to BROWSERS in this script.')
  process.exit(1)
}

mkdirSync(SHOTS, { recursive: true })

const problems = []
const results = []
const check = (name, ok, detail = '') => {
  results.push({ name, ok, detail })
  if (!ok) problems.push(name + (detail ? ' - ' + detail : ''))
  console.log((ok ? '  PASS  ' : '  FAIL  ') + name + (detail ? '  (' + detail + ')' : ''))
}

const browser = await chromium.launch({ executablePath, headless: true })
const page = await browser.newPage({ viewport: { width: 1500, height: 1100 } })

// Any uncaught error or console error is a failure. Silent JS breakage is the
// exact class of bug a build cannot catch.
page.on('pageerror', (e) => problems.push('PAGE ERROR: ' + e.message))
page.on('console', (m) => {
  if (m.type() === 'error') problems.push('CONSOLE ERROR: ' + m.text().slice(0, 300))
})

const shot = (name) => page.screenshot({ path: resolve(SHOTS, name + '.png'), fullPage: true })

try {
  console.log('base ' + BASE + ' | user ' + EMAIL + ' | date ' + DATE + (BUILD ? ' | RUNNING A BUILD' : ''))

  // ---- login ----
  await page.goto(BASE + '/login', { waitUntil: 'networkidle' })
  await page.fill('input[type=email]', EMAIL)
  await page.fill('input[type=password]', PASSWORD)
  await page.click('button[type=submit]')
  await page.waitForURL((u) => !u.pathname.includes('login'), { timeout: 20000 })
  check('login', true, page.url())
  await shot('01-home')

  // ---- the main screens render ----
  for (const [name, path] of [
    ['settings', '/settings'],
    ['team setup - employees & training', '/details?tab=employees'],
    ['team setup - job functions', '/details?tab=job-functions'],
    ['old /training address redirects', '/training'],
    ['pto calendar', '/pto-calendar'],
    ['employee overview', '/employee-overview'],
    ['create schedule', '/schedule/tomorrow'],
    ['schedule day', '/schedule/' + DATE],
    ['display board', '/display'],
  ]) {
    await page.goto(BASE + path, { waitUntil: 'networkidle' })
    await page.waitForTimeout(1200)
    const text = await page.locator('body').innerText()
    check('renders ' + name, text.trim().length > 50, path)
    await shot('page-' + name.replace(/\s+/g, '-'))
  }

  // ---- optionally run a real build (WRITES to the database) ----
  if (BUILD) {
    await page.goto(BASE + '/schedule/tomorrow', { waitUntil: 'networkidle' })
    await page.fill('#schedule-date', DATE)
    await page.waitForTimeout(2000)
    await page.getByText('Automated Schedule Builder', { exact: false }).first().click()
    await page.waitForSelector('text=/Schedule Generation Complete|could not be generated/i', { timeout: 180000 })
    await page.waitForTimeout(1500)
    const modal = await page.locator('body').innerText()
    const failed = /Schedule could not be generated/i.test(modal)
    check('build succeeded', !failed, failed ? 'failure banner shown' : 'success banner shown')
    await shot('build-result')
  }
} catch (e) {
  problems.push('THREW: ' + e.message)
} finally {
  await browser.close()
}

console.log('\nscreenshots: ' + SHOTS)
if (problems.length) {
  console.log('\n' + problems.length + ' problem(s):')
  for (const p of problems) console.log('  - ' + p)
  process.exit(1)
}
console.log('\nall ' + results.length + ' checks passed, no JS errors')
