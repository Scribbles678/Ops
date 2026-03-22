import { query } from '../utils/db'

export default defineEventHandler(async () => {
  try {
    await query('SELECT 1')
    return { status: 'ok', database: 'connected', timestamp: new Date().toISOString() }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown error'
    throw createError({
      statusCode: 503,
      message: `Database unavailable: ${message}`,
    })
  }
})
