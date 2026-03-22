import jwt from 'jsonwebtoken'
import type { AuthUser } from './authorize'

const COOKIE_NAME = 'auth_token'
const TOKEN_EXPIRY = '8h'

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
    },
    getJwtSecret(),
    { expiresIn: TOKEN_EXPIRY }
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
