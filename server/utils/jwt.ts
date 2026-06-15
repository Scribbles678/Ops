import jwt from 'jsonwebtoken'
import type { AuthUser } from './authorize'

const COOKIE_NAME = 'auth_token'
const TOKEN_EXPIRY = '8h'
// Display-only (kiosk) accounts run a wall/iPad 24/7 — give them a long-lived,
// self-renewing session so they don't get logged out overnight. The display page
// also slides the window via /api/auth/refresh, so a running kiosk never expires.
const DISPLAY_TOKEN_EXPIRY = '30d'
export const SESSION_MAX_AGE_SECONDS = 60 * 60 * 8
export const DISPLAY_SESSION_MAX_AGE_SECONDS = 60 * 60 * 24 * 30
export const sessionMaxAge = (user: { is_display_user?: boolean }): number =>
  user.is_display_user ? DISPLAY_SESSION_MAX_AGE_SECONDS : SESSION_MAX_AGE_SECONDS

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
      is_display_user: user.is_display_user,
      is_active: user.is_active,
      employee_id: user.employee_id ?? null,
    },
    getJwtSecret(),
    { expiresIn: user.is_display_user ? DISPLAY_TOKEN_EXPIRY : TOKEN_EXPIRY }
  )
}

export function verifyToken(token: string): AuthUser | null {
  try {
    const payload = jwt.verify(token, getJwtSecret()) as AuthUser
    return payload
  } catch {
    return null
  }
}

export { COOKIE_NAME }
