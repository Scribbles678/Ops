// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },

  modules: [
    '@nuxtjs/tailwindcss',
  ],

  ssr: false, // Avoids "instance unavailable" with useState during Nitro SSR

  tailwindcss: {
    cssPath: '~/assets/css/main.css',
    configPath: 'tailwind.config.js',
  },

  app: {
    head: {
      title: 'Operations Scheduling Tool',
      meta: [
        { name: 'description', content: 'Distribution Center Scheduling Application' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      ],
    },
  },

  runtimeConfig: {
    // Server-only secrets (never exposed to client)
    databaseUrl: process.env.DATABASE_URL || '',
    jwtSecret: process.env.JWT_SECRET || '',
    appUrl: process.env.APP_URL || 'http://localhost:3000',
    public: {
      appName: 'Operations Scheduling Tool',
    },
  },

  nitro: {
    experimental: {
      wasm: true,
    },
  },
})
