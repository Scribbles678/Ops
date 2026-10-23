import { query, transaction } from '../../../utils/db'
import { requireSupervisor } from '../../../utils/authorize'
import { assertAccountManageable } from '../../../utils/teamOwnership'
import { assertNewPassword, setPassword } from '../../../utils/password'
import { logAccountChange, describeAccount } from '../../../utils/auditLog'

/**
 * Settings → Users → Reset password: set a new password for someone else.
 *
 * Signs them out on every device (setPassword → password_changed_at), cancels any
 * emailed reset link, and is written to the change log (no password in it).
 * Your OWN password is refused here: My account → Change password asks for the
 * current one, and this didn't — anyone at an unlocked supervisor screen could set
 * a new password and lock the real owner out (Oct 2026).
 */
export default defineEventHandler(async (event) => {
  if (event.method !== 'POST') {
    throw createError({ statusCode: 405, message: 'Method not allowed' })
  }

  // A supervisor resets passwords on their own team's accounts, other than Super
  // Admins; a super admin, on any account.
  const actor = requireSupervisor(event)

  const body = await readBody(event)
  const { user_id } = body ?? {}
  if (!user_id) {
    throw createError({ statusCode: 400, message: 'User ID and new password are required' })
  }
  const newPassword = assertNewPassword(body?.new_password)

  if (user_id === actor.id) {
    throw createError({
      statusCode: 400,
      message: 'Change your own password in Settings → My account — it asks for your current one.',
    })
  }
  await assertAccountManageable(actor, user_id)

  const target = (await query<{ id: string; email: string; full_name: string | null; team_id: string | null }>(
    'SELECT id, email, full_name, team_id FROM user_profiles WHERE id = $1',
    [user_id]
  )).rows[0]!

  await transaction(async (client) => {
    await setPassword(client, user_id, newPassword)
    await logAccountChange(client, {
      actor,
      account: target,
      summary: `Reset the password for ${describeAccount(target)}. They were signed out on every device.`,
    })
  })

  return { success: true, message: 'Password reset successfully' }
})
