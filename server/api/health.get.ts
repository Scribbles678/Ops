import { query } from '../utils/db'
import { startup } from '../utils/startup'

/**
 * 503 while the app is still waiting for / setting up its database, or when the
 * database cannot be reached. A restart cannot make either worse.
 *
 * Once running, it also reports whether the app's tables exist — but still answers
 * 200 when they do not (the database was emptied or replaced under a running app).
 * If this is wired as a LIVENESS probe, failing here would restart the pod, and a
 * restart builds a fresh empty install: in the middle of a restore, that is worse
 * than an error. It says so plainly and leaves the decision to a person.
 */
export default defineEventHandler(async () => {
  if (!startup.ready) {
    throw createError({
      statusCode: 503,
      message: startup.failure
        ? `Database setup failed: ${startup.failure}`
        : 'Starting up: waiting for the database, or setting it up',
    })
  }
  try {
    const result = await query<{ present: boolean }>(`SELECT to_regclass('public.user_profiles') IS NOT NULL AS present`)
    const tables = result.rows[0]?.present ? 'present' : 'missing'
    return {
      status: tables === 'present' ? 'ok' : 'no-tables',
      database: 'connected',
      tables,
      timestamp: new Date().toISOString(),
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error'
    throw createError({
      statusCode: 503,
      message: `Database unavailable: ${message}`,
    })
  }
})
