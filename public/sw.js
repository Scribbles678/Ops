// Empty service worker file to suppress warnings
// This app doesn't use service workers, but browsers may request this file
self.addEventListener('install', () => {
  self.skipWaiting()
})

self.addEventListener('activate', () => {
  self.clients.claim()
})
