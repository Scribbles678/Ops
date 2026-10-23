<template>
  <div>
    <!-- "Working in <team>" for accounts with more than one team (migration 027). -->
    <TeamBar />
    <NuxtPage />
    <!-- Non-blocking "Saved" / "Couldn't save" notices for every page (useToast). -->
    <AppToasts />
    <!-- "Your session ended — sign in again", over whatever page was open
         (plugins/session.client.ts raises it on any 401). -->
    <SessionEndedModal />
  </div>
</template>
