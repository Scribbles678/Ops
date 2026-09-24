import { clearSessionCookie } from '../../utils/jwt'

export default defineEventHandler((event) => {
  clearSessionCookie(event)
  return { success: true }
})
