import jwt from 'jsonwebtoken'
import { setCookie, deleteCookie, getRequestProtocol, type H3Event } from 'h3'
import type { AuthUser } from './authorize'

const COOKIE_NAME = 'auth_token'
// Sessions slide: server/middleware/auth.ts re-issues the cookie while the account
// is in use (see SESSION_RENEW_AFTER_SECONDS), so these are the IDLE limits — a
// person is signed out after 8 hours without using the app, never mid-shift.
const TOKEN_EXPIRY = '8h'
// Display-only (kiosk) accounts run a wall/iPad 24/7 — give them a long-lived
// session so they don't get logged out overnight.
const DISPLAY_TOKEN_EXPIRY = '30d'
export const SESSION_MAX_AGE_SECONDS = 60 * 60 * 8
export const DISPLAY_SESSION_MAX_AGE_SECONDS = 60 * 60 * 24 * 30
export const sessionMaxAge = (user: { is_display_user?: boolean }): number =>
  user.is_display_user ? DISPLAY_SESSION_MAX_AGE_SECONDS : SESSION_MAX_AGE_SECONDS
/** Re-issue a session cookie at most this often while it is being used. */
export const SESSION_RENEW_AFTER_SECONDS = 10 * 60

/**
 * Set the session cookie for `user`.
 *
 * `secure` follows how the browser actually reached us — HTTPS directly, or via an
 * ingress that says so in X-Forwarded-Proto. It used to be
 * `process.env.NODE_ENV === 'production'`, which the build fixes to true: a site
 * that opened the app over plain http:// got a cookie its browser threw away, so
 * sign-in "worked" and every later call was a 401 (Sep 2026, the second site).
 * HTTPS on the ingress is still the right setup; this just stops http:// failing
 * silently.
 */
export function setSessionCookie(event: H3Event, user: AuthUser): void {
  setCookie(event, COOKIE_NAME, signToken(user), {
    httpOnly: true,
    secure: getRequestProtocol(event) === 'https',
    sameSite: 'strict',
    maxAge: sessionMaxAge(user),
    path: '/',
  })
}

export function clearSessionCookie(event: H3Event): void {
  deleteCookie(event, COOKIE_NAME, {
    httpOnly: true,
    secure: getRequestProtocol(event) === 'https',
    sameSite: 'strict',
    path: '/',
  })
}

function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET
  if (!secret || secret.length < 32) {
    throw new Error('JWT_SECRET environment variable must be set and at least 32 characters')
  }
  return secret
}

export function signToken(user: AuthUser): string {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      username: user.username,
      full_name: user.full_name,
      team_id: user.team_id,
      is_admin: user.is_admin,
      is_super_admin: user.is_super_admin,
      is_team_lead: user.is_team_lead ?? false,
      is_display_user: user.is_display_user,
      is_active: user.is_active,
      employee_id: user.employee_id ?? null,
    },
    getJwtSecret(),
    { expiresIn: user.is_display_user ? DISPLAY_TOKEN_EXPIRY : TOKEN_EXPIRY }
  )
}

/**
 * Check the signature and expiry. The claims say WHO the caller is and when the
 * token was issued (`iat`, seconds); what they may do comes from the database —
 * see server/middleware/auth.ts.
 */
export function verifyToken(token: string): (AuthUser & { iat?: number }) | null {
  try {
    return jwt.verify(token, getJwtSecret()) as AuthUser & { iat?: number }
  } catch {
    return null
  }
}

export { COOKIE_NAME }
