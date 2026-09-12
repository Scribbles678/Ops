/**
 * employees.upi — a numeric identifier, digits only, up to 20 (matches the CHECK
 * constraint from migration 020). Blank means "none"; anything else must be digits.
 *
 * Returns the value to store, or throws a 400 the form can show.
 */
export function normalizeUpi(raw: unknown): string | null {
  if (raw == null) return null
  const s = String(raw).trim()
  if (!s) return null
  if (!/^[0-9]{1,20}$/.test(s)) {
    throw createError({ statusCode: 400, message: 'UPI must be numbers only (up to 20 digits)' })
  }
  return s
}

/** Postgres unique_violation on the per-team UPI index. */
export const isUpiTaken = (e: any): boolean =>
  e?.code === '23505' && String(e?.constraint ?? '').includes('upi')
