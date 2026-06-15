import { signToken, COOKIE_NAME, sessionMaxAge } from '../../utils/jwt'
import { requireAuth } from '../../utils/authorize'

/**
 * Slide the session: if the caller's token is still valid, re-issue it (fresh
 * expiry) and re-set the cookie. The /display kiosk pings this on every refresh so
 * a 24/7 wall display never gets logged out. Returns 401 if the token has expired.
 */
export default defineEventHandler((event) => {
  const user = requireAuth(event)
  const token = signToken(user)
  setCookie(event, COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: sessionMaxAge(user),
    path: '/',
  })
  return { success: true }
})
