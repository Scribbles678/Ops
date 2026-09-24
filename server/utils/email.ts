/**
 * Email utility for sending transactional emails (e.g. password reset).
 * Uses SMTP via nodemailer. Configure via env: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, etc.
 */

import nodemailer from 'nodemailer'

const config = useRuntimeConfig()

export interface EmailOptions {
  to: string
  subject: string
  html: string
  text?: string
}

/**
 * Send an email. Returns true if sent, false if email is not configured or failed.
 * Never throws - log errors and return false so caller can show generic success message.
 */
export async function sendEmail(options: EmailOptions): Promise<boolean> {
  const host = process.env.SMTP_HOST
  const port = parseInt(process.env.SMTP_PORT || '587', 10)
  const user = process.env.SMTP_USER
  const pass = process.env.SMTP_PASS
  const from = process.env.SMTP_FROM || process.env.SMTP_USER || 'noreply@example.com'

  if (!host || !user || !pass) {
    console.warn('[email] SMTP not configured (SMTP_HOST, SMTP_USER, SMTP_PASS). Skipping send.')
    return false
  }

  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass }
    })

    await transporter.sendMail({
      from,
      to: options.to,
      subject: options.subject,
      html: options.html,
      text: options.text || options.html.replace(/<[^>]*>/g, '')
    })

    return true
  } catch (err) {
    console.error('[email] Failed to send:', err)
    return false
  }
}

/**
 * Build the base URL for reset links (e.g. https://scheduler.example.com).
 *
 * APP_URL is read at RUN time first. `config.appUrl` is fixed when the image is
 * built (nuxt.config reads APP_URL then, which the build doesn't have), so it was
 * always "http://localhost:3000" and every reset email linked there, whatever the
 * deployment set. NUXT_APP_URL also works: Nuxt applies it to config.appUrl.
 */
export function getAppBaseUrl(): string {
  return (process.env.APP_URL || config.appUrl || 'http://localhost:3000').replace(/\/+$/, '')
}
