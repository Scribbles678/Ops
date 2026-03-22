import { COOKIE_NAME } from '../../utils/jwt'

export default defineEventHandler((event) => {
  deleteCookie(event, COOKIE_NAME, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    path: '/',
  })
  return { success: true }
})
