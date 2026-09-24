<template>
  <div>
    <NuxtPage />
    <!-- Non-blocking "Saved" / "Couldn't save" notices for every page (useToast). -->
    <AppToasts />
    <!-- "Your session ended — sign in again", over whatever page was open
         (plugins/session.client.ts raises it on any 401). -->
    <SessionEndedModal />
  </div>
</template>
