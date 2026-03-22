/**
 * Global route middleware - replaces @nuxtjs/supabase auth redirect handling.
 * On server: skip composables (useState/useRequestEvent cause "instance unavailable" in Nitro SSR).
 * On client: use useAuth for redirects.
 */
export default defineNuxtRouteMiddleware(async (to) => {
  const publicRoutes = ['/login', '/display', '/reset-password']
  const isPublicRoute = publicRoutes.includes(to.path)

  // SERVER: Skip auth check to avoid useState/useNuxtApp - let page render, client will redirect
  if (import.meta.server) {
    return
  }

  // CLIENT: Use useAuth composable
  const { user, fetchCurrentUser } = useAuth()

  if (user.value === null && !isPublicRoute) {
    await fetchCurrentUser()
  }

  if (user.value && to.path === '/login') return navigateTo('/')
  if (!user.value && !isPublicRoute) return navigateTo('/login')
})
