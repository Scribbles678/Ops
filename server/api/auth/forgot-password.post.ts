import crypto from 'node:crypto'
import bcrypt from 'bcryptjs'
import { query } from '../../utils/db'
import { sendEmail, getAppBaseUrl } from '../../utils/email'

const TOKEN_EXPIRY_HOURS = 1
const TOKEN_BYTES = 32

export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const email = body?.email?.trim()?.toLowerCase()

  if (!email) {
    throw createError({ statusCode: 400, message: 'Email is required' })
  }

  // Fetch user by email (only if active)
  const result = await query<{ id: string; full_name: string | null }>(
    `SELECT id, full_name FROM user_profiles WHERE email = $1 AND is_active = true LIMIT 1`,
    [email]
  )

  const user = result.rows[0]

  // Always return success to avoid leaking whether the email exists
  // If user not found, we still "succeed" but do nothing
  if (!user) {
    return { success: true, message: 'If that email is registered, you will receive a reset link.' }
  }

  const tokenId = crypto.randomUUID()
  const secret = crypto.randomBytes(TOKEN_BYTES).toString('hex')
  const tokenHash = await bcrypt.hash(secret, 10)
  const expiresAt = new Date(Date.now() + TOKEN_EXPIRY_HOURS * 60 * 60 * 1000)

  await query(
    `INSERT INTO password_reset_tokens (id, user_id, token_hash, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [tokenId, user.id, tokenHash, expiresAt]
  )

  const rawToken = `${tokenId}.${secret}`
  const resetUrl = `${getAppBaseUrl()}/reset-password?token=${encodeURIComponent(rawToken)}`
  const displayName = user.full_name || email
  const sent = await sendEmail({
    to: email,
    subject: 'Reset your password - Operations Scheduler',
    html: `
      <p>Hi ${escapeHtml(displayName)},</p>
      <p>You requested a password reset for the Operations Scheduler. Click the link below to set a new password:</p>
      <p><a href="${resetUrl}">${resetUrl}</a></p>
      <p>This link expires in ${TOKEN_EXPIRY_HOURS} hour(s). If you didn't request this, you can ignore this email.</p>
      <p>— Operations Scheduler</p>
    `
  })

  if (!sent) {
    console.error('[forgot-password] Failed to send email to', email)
    // Still return success - don't leak that email exists or that email failed
  }

  return { success: true, message: 'If that email is registered, you will receive a reset link.' }
})

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}
