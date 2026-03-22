import { verifyToken, COOKIE_NAME } from '../utils/jwt'

/**
 * Global server middleware that reads the JWT auth cookie on every request
 * and populates event.context.user for downstream API route handlers.
 *
 * Routes that require auth call requireAuth(event) from server/utils/authorize.ts.
 * Routes that don't need auth (login, display) simply don't call requireAuth.
 */
export default defineEventHandler((event) => {
  const token = getCookie(event, COOKIE_NAME)

  if (token) {
    const user = verifyToken(token)
    if (user) {
      event.context.user = user
    }
  }
})
