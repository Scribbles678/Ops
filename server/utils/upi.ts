import { query } from './db'

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

/**
 * The 409 for a UPI that's already in use, naming who has it. That person may be
 * inactive — out of sight in Team Setup's collapsed "Inactive" list — so say so.
 */
export async function upiTakenError(upi: string | null, teamId: string) {
  const holder = (await query<{ first_name: string; last_name: string; is_active: boolean }>(
    'SELECT first_name, last_name, is_active FROM employees WHERE upi = $1 AND team_id = $2',
    [upi, teamId]
  )).rows[0]
  return createError({
    statusCode: 409,
    message: holder
      ? `UPI ${upi} already belongs to ${holder.last_name}, ${holder.first_name}${holder.is_active ? '' : ' (inactive)'}.`
      : `UPI ${upi} is already assigned to another employee`,
  })
}
