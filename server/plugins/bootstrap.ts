/**
 * Self-bootstrap: on container startup, make sure the database is fully set up
 * and a first admin user exists. Idempotent — safe to re-run on every pod boot.
 *
 * Order of operations:
 *   1. Acquire a Postgres advisory lock (prevents races across replicas).
 *   2. If no schema present → run sql-schema/setup.sql.
 *   3. Apply every sql-schema/migrations/*.sql in filename order.
 *      All migrations use CREATE/ALTER ... IF NOT EXISTS so re-running is safe.
 *   4. If user_profiles is empty → create the first super admin from env vars
 *      ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_NAME. Otherwise skip.
 *   5. Release the lock.
 *
 * Nitro does NOT wait for this plugin: the server is already taking requests while
 * it runs. So it first waits for the database to answer (retrying for as long as
 * it takes), and until setup has finished `startup.ready` stays false and API calls
 * get a 503 (server/middleware/0.startup.ts) instead of hitting missing tables.
 *
 * If a step fails in a built app, the process exits so the pod restarts and the
 * failure shows as a crashloop (`npm run dev` stays up and shows the error instead). Until Sep 2026 this "threw" instead — which Nitro
 * only logs as an unhandled rejection — so a failed setup left the app serving a
 * database with no tables (`relation "pto_days" does not exist`) until someone
 * restarted it.
 */

import { readFile, readdir, stat } from 'node:fs/promises'
import { join, resolve } from 'node:path'
import bcrypt from 'bcryptjs'
import { getPool } from '../utils/db'
import { startup } from '../utils/startup'

const BOOTSTRAP_LOCK_ID = 912358401
/** Longest pause between attempts while waiting for the database to come up. */
const DB_WAIT_MAX_DELAY_MS = 10_000
/** While waiting, log the first failed attempt and then every Nth, not each one. */
const DB_WAIT_LOG_EVERY = 10

// Nitro runs the compiled bundle from /app/.output/server, so sql-schema lives
// up one level. In dev mode (`npm run dev`) it's at the project root.
const SCHEMA_DIR_CANDIDATES = [
  resolve(process.cwd(), 'sql-schema'),
  resolve(process.cwd(), '../sql-schema'),
  resolve(process.cwd(), '../../sql-schema'),
]

export default defineNitroPlugin(() => {
  if (!process.env.DATABASE_URL) {
    console.warn('[bootstrap] DATABASE_URL not set — skipping')
    startup.ready = true
    return
  }
  // Not awaited by Nitro either way; setUp() tracks its own outcome in `startup`.
  void setUp()
})

async function setUp(): Promise<void> {
  await waitForDatabase()
  try {
    await runBootstrap()
    startup.ready = true
  } catch (err: any) {
    const reason = err?.message || String(err)
    console.error('[bootstrap] FAILED:', reason)
    // A built app (Docker / Rancher) exits so the pod restarts. `import.meta.dev`,
    // not NODE_ENV: the build inlines NODE_ENV as "production", so only the dev
    // server can tell it is one.
    if (!import.meta.dev) {
      console.error('[bootstrap] exiting so the pod restarts rather than serve a half-set-up database')
      process.exit(1)
    }
    // `npm run dev`: stay up so the error is readable; API calls get a 503 quoting it.
    startup.failure = reason
  }
}

/**
 * After a node drain the app and database pods start together and the app
 * usually wins. Until Sep 2026 the first failed connection ended setup for good.
 * Keep trying until the database answers.
 */
async function waitForDatabase(): Promise<void> {
  for (let attempt = 1; ; attempt++) {
    try {
      await getPool().query('SELECT 1')
      if (attempt > 1) console.log('[bootstrap] database is up')
      return
    } catch (err: any) {
      if (attempt === 1 || attempt % DB_WAIT_LOG_EVERY === 0) {
        console.warn(`[bootstrap] waiting for the database (${err?.message || err}) — retrying`)
      }
      await new Promise((r) => setTimeout(r, Math.min(DB_WAIT_MAX_DELAY_MS, 1000 * attempt)))
    }
  }
}

async function runBootstrap() {
  const schemaDir = await findSchemaDir()
  if (!schemaDir) {
    console.warn('[bootstrap] sql-schema folder not found — skipping (dev mode or missing files)')
    return
  }

  const pool = getPool()
  const client = await pool.connect()
  try {
    await client.query('SELECT pg_advisory_lock($1)', [BOOTSTRAP_LOCK_ID])

    const schemaReady = await hasUserProfilesTable(client)
    if (!schemaReady) {
      console.log('[bootstrap] no schema detected — applying setup.sql')
      const setupSql = await readFile(join(schemaDir, 'setup.sql'), 'utf8')
      await client.query(setupSql)
      console.log('[bootstrap]   ✓ base schema created')
    } else {
      console.log('[bootstrap] base schema already present')
    }

    const migrationsDir = join(schemaDir, 'migrations')
    const migrationFiles = await listMigrations(migrationsDir)
    if (migrationFiles.length > 0) {
      console.log(`[bootstrap] applying ${migrationFiles.length} migration(s)`)
      for (const file of migrationFiles) {
        try {
          const sql = await readFile(join(migrationsDir, file), 'utf8')
          await client.query(sql)
          console.log(`[bootstrap]   ✓ ${file}`)
        } catch (e: any) {
          console.error(`[bootstrap]   ✗ ${file}: ${e?.message || e}`)
          throw e
        }
      }
    }

    await maybeSeedFirstAdmin(client)

    await client.query('SELECT pg_advisory_unlock($1)', [BOOTSTRAP_LOCK_ID])
    console.log('[bootstrap] done')
  } finally {
    client.release()
  }
}

async function findSchemaDir(): Promise<string | null> {
  for (const dir of SCHEMA_DIR_CANDIDATES) {
    try {
      await stat(join(dir, 'setup.sql'))
      return dir
    } catch {
      /* try next candidate */
    }
  }
  return null
}

async function hasUserProfilesTable(client: any): Promise<boolean> {
  const result = await client.query(
    `SELECT EXISTS (
       SELECT 1 FROM information_schema.tables
       WHERE table_schema = 'public' AND table_name = 'user_profiles'
     ) as exists`
  )
  return !!result.rows[0]?.exists
}

async function listMigrations(dir: string): Promise<string[]> {
  try {
    const files = await readdir(dir)
    return files.filter((f) => f.endsWith('.sql')).sort()
  } catch {
    return []
  }
}

async function maybeSeedFirstAdmin(client: any): Promise<void> {
  const countResult = await client.query('SELECT COUNT(*)::int AS cnt FROM user_profiles')
  const count = Number(countResult.rows[0]?.cnt ?? 0)
  if (count > 0) {
    console.log(`[bootstrap] ${count} user(s) already exist — skipping admin seed`)
    return
  }

  // Default credentials are used only if ADMIN_EMAIL/ADMIN_PASSWORD aren't set.
  // Deploy-friendly: the app always has a working first login. You're expected
  // to change the password immediately after first login (Settings → Change Password).
  const DEFAULT_EMAIL = 'admin@example.com'
  const DEFAULT_PASSWORD = 'admin123'

  const email = process.env.ADMIN_EMAIL || DEFAULT_EMAIL
  const password = process.env.ADMIN_PASSWORD || DEFAULT_PASSWORD
  const name = process.env.ADMIN_NAME || 'Admin User'
  const usingDefaults = !process.env.ADMIN_EMAIL || !process.env.ADMIN_PASSWORD

  const username = email.split('@')[0] || email
  const passwordHash = bcrypt.hashSync(password, 10)

  // Reuse any existing team, or create a default one
  const teamResult = await client.query<{ id: string }>('SELECT id FROM teams ORDER BY created_at ASC LIMIT 1')
  let teamId = (teamResult.rows[0] as any)?.id as string | undefined
  if (!teamId) {
    const created = await client.query<{ id: string }>(
      `INSERT INTO teams (name) VALUES ('Default Team') RETURNING id`
    )
    teamId = (created.rows[0] as any).id
  }

  await client.query(
    `INSERT INTO user_profiles (username, email, password_hash, full_name, team_id, is_super_admin, is_active)
     VALUES ($1, $2, $3, $4, $5, true, true)
     ON CONFLICT (email) DO NOTHING`,
    [username, email, passwordHash, name, teamId]
  )
  console.log(`[bootstrap]   ✓ first super admin created: ${email}`)
  if (usingDefaults) {
    console.warn(
      '[bootstrap]   ⚠ USING DEFAULT CREDENTIALS ⚠\n' +
        `            Email:    ${email}\n` +
        `            Password: ${password}\n` +
        '            Log in, then go to Settings → Change Password to replace them immediately.'
    )
  }
}
