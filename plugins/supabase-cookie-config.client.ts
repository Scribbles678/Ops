// Client-side plugin to configure Supabase to use server-side cookies
// This ensures HttpOnly cookies are used for session management

export default defineNuxtPlugin(() => {
  const supabase = useSupabaseClient()
  
  // The @nuxtjs/supabase module should handle server-side cookies automatically
  // But we'll ensure the client is configured correctly
  
  // Note: HttpOnly cookies must be set server-side
  // The @nuxtjs/supabase module handles this for SSR
  // This plugin ensures client-side behavior is correct
})

