// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  
  modules: [
    '@nuxtjs/tailwindcss',
    '@nuxtjs/supabase'
  ],
  
  // Fix hydration issues
  ssr: true,
  
  tailwindcss: {
    cssPath: '~/assets/css/main.css',
    configPath: 'tailwind.config.js'
  },
  
  // Supabase configuration
  supabase: {
    redirect: false, // We'll handle redirects manually in middleware
    redirectOptions: {
      login: '/login',
      exclude: ['/login', '/display', '/reset-password'] // Display mode and reset password are public
    },
    url: process.env.SUPABASE_URL,
    key: process.env.SUPABASE_ANON_KEY,
  },
  
  app: {
    head: {
      title: 'Operations Scheduling Tool',
      meta: [
        { name: 'description', content: 'Distribution Center Scheduling Application' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' }
      ]
    }
  },
  
  runtimeConfig: {
    // Server-only (never exposed to client)
    supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
    public: {
      supabaseUrl: process.env.SUPABASE_URL || '',
      supabaseKey: process.env.SUPABASE_ANON_KEY || ''
      // Removed appPassword - no longer needed
    }
  },
  
  // Fix hydration mismatches
  nitro: {
    experimental: {
      wasm: true
    },
    // Handle service worker routes gracefully
    routeRules: {
      '/sw.js': { prerender: true, headers: { 'Cache-Control': 'public, max-age=31536000' } }
    }
  }
})
