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

  // Display-only (kiosk) accounts are locked to the display page: they can't reach
  // any other route, even by typing the URL. /display is public, so this only fires
  // for an authenticated display user trying to go elsewhere.
  if (user.value?.is_display_user && to.path !== '/display') {
    return navigateTo('/display')
  }

  if (user.value && to.path === '/login') {
    return navigateTo(user.value.is_display_user ? '/display' : '/')
  }
  if (!user.value && !isPublicRoute) return navigateTo('/login')
})
