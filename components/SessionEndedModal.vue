<template>
  <div
    v-if="sessionEnded"
    class="fixed inset-0 z-[100] bg-black/60 flex items-center justify-center p-4"
    role="dialog"
    aria-modal="true"
    aria-labelledby="session-ended-title"
  >
    <form class="bg-white rounded-lg shadow-xl w-full max-w-sm p-5 space-y-3" @submit.prevent="signIn">
      <h2 id="session-ended-title" class="text-lg font-semibold text-gray-900">
        {{ onDisplay ? 'This display needs to sign in' : 'Your session ended' }}
      </h2>
      <p class="text-sm text-gray-600">
        {{ onDisplay
          ? "Sign in with this site's kiosk account."
          : "Sign in again to carry on. This page stays as it is, so anything you haven't saved is still here." }}
      </p>
      <div>
        <label for="session-email" class="block text-sm font-medium text-gray-700 mb-1">Email</label>
        <input
          id="session-email"
          v-model="email"
          type="email"
          required
          autocomplete="username"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      <div>
        <label for="session-password" class="block text-sm font-medium text-gray-700 mb-1">Password</label>
        <input
          id="session-password"
          v-model="password"
          type="password"
          required
          autocomplete="current-password"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      <p v-if="error" role="alert" class="text-sm text-red-700 bg-red-50 border border-red-200 rounded-md px-3 py-2">
        {{ error }}
      </p>
      <div class="flex items-center justify-between gap-3 pt-1">
        <a href="/login" class="text-sm text-gray-600 hover:text-gray-800 underline">Go to the sign-in page</a>
        <button type="submit" :disabled="busy" class="btn-primary disabled:opacity-50">
          {{ busy ? 'Signing in…' : 'Sign in' }}
        </button>
      </div>
    </form>
  </div>
</template>

<script setup lang="ts">
// Raised by plugins/session.client.ts when an API call returns 401. Signing back in
// here as the same person keeps the page exactly as it was, unsaved edits included
// (the schedule editor guards in-app navigation, not reloads). Anyone else, or the
// same person now on another team, gets a fresh page so no one works on — or saves
// into — a screen that belonged to someone else.
const { user, sessionEnded, login } = useAuth()
const route = useRoute()
const onDisplay = computed(() => route.path === '/display')

const email = ref('')
const password = ref('')
const error = ref('')
const busy = ref(false)

watch(sessionEnded, (ended) => {
  if (!ended) return
  email.value = user.value?.email ?? ''
  password.value = ''
  error.value = ''
}, { immediate: true })

const signIn = async () => {
  busy.value = true
  error.value = ''
  const before = user.value
  try {
    const now = await login(email.value.trim().toLowerCase(), password.value, {
      // The wall display runs as its kiosk account. Whoever was already signed in
      // there (a supervisor viewing Display Mode on their own PC) may sign back in.
      kioskOnly: onDisplay.value && !(before && email.value.trim().toLowerCase() === before.email),
    })
    if (!before || now.id !== before.id || now.team_id !== before.team_id) {
      window.location.reload()
      return
    }
    password.value = ''
  } catch (e: any) {
    error.value = e?.data?.message ?? e?.message ?? 'Sign-in failed'
  } finally {
    busy.value = false
  }
}
</script>
