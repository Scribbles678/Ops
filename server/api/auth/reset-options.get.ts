import { isEmailConfigured } from '../../utils/email'

/**
 * Public: can this site email a password-reset link? The "Forgot your password?"
 * page asks before showing its form, so that without email it says to ask a
 * supervisor instead of promising a link that never comes. Says nothing about any
 * account.
 */
export default defineEventHandler(() => ({ emailLinks: isEmailConfigured() }))
