// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  
  modules: ['@nuxtjs/tailwindcss'],
  
  // Fix hydration issues
  ssr: true,
  
  tailwindcss: {
    cssPath: '~/assets/css/main.css',
    configPath: 'tailwind.config.js'
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
    public: {
      supabaseUrl: process.env.SUPABASE_URL || '',
      supabaseAnonKey: process.env.SUPABASE_ANON_KEY || '',
      appPassword: process.env.APP_PASSWORD || 'operations2024'
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
