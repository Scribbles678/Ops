import { requireAuth } from '../../utils/authorize'

export default defineEventHandler((event) => {
  const user = requireAuth(event)
  return { user }
})
