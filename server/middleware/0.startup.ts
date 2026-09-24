import { startup } from '../utils/startup'

/**
 * Until the startup database setup has finished, answer API calls with 503 rather
 * than run them against tables that may not exist yet. Named with a leading 0 so
 * it runs before the other middleware. /api/health reports the same state itself.
 */
export default defineEventHandler((event) => {
  if (startup.ready || !event.path.startsWith('/api/') || event.path.startsWith('/api/health')) return
  throw createError({
    statusCode: 503,
    message: startup.failure
      ? `The app could not set up its database: ${startup.failure}`
      : 'The app is starting up. Try again in a moment.',
  })
})
