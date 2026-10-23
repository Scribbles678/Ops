<!--
  Employees & Training — the first tab of Team Setup (pages/details.vue).

  Every change saves on its own, the moment it's made:
  - a training box sends just that change (useTrainingSaves → POST
    /api/employees/:id/training { add | remove }), one at a time per person;
  - the shift dropdown saves that one field (useBoxSave, namespace 'employee-shift');
  - add / edit / delete / deactivate go through a window and end in a toast.
  Each inline save shows its own status beside the control (<UiSaveStatus>).

  What this replaced: a 1.5 s debounce that sent each person's WHOLE training set,
  then reloaded everyone's training and wiped everyone's unsent clicks — so ticking
  two people a second apart lost the second tick, and a failed load ("trained on
  nothing") plus one tick erased all of someone's training.

  Both savers keep their state outside this component, so switching tabs mid-save
  loses nothing and a failure after the tab closed comes back as a toast. Warning
  on leaving the page mid-save is the page's job (useLeaveGuard), not this tab's.
-->
<template>
  <div class="text-xs md:text-sm">
    <!-- Search -->
    <div class="card mb-3">
      <label :for="`${uid}-search`" class="sr-only">Search employees by name or UPI</label>
      <input
        :id="`${uid}-search`"
        v-model="searchQuery"
        type="search"
        placeholder="Search by name or UPI…"
        class="w-full px-2.5 py-1.5 border border-gray-300 rounded-lg focus:outline-none focus:ring-1 focus:ring-blue-500 text-xs md:text-sm"
      />
    </div>

    <!-- Header -->
    <div class="card mb-3">
      <div class="flex flex-wrap justify-between items-center gap-2">
        <h2 class="text-base md:text-lg font-semibold text-gray-800">Employees &amp; Training</h2>
        <div class="flex flex-wrap gap-2">
          <!-- Deactivated people are kept in their own list at the bottom; this finds it. -->
          <button
            v-if="inactiveCount"
            type="button"
            class="px-3 py-1.5 rounded-md text-xs md:text-sm font-medium bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
            @click="showInactive"
          >
            Inactive ({{ inactiveCount }})
          </button>
          <NuxtLink
            to="/employee-overview"
            class="px-3 py-1.5 rounded-md text-xs md:text-sm font-medium bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
          >
            Employee Overview
          </NuxtLink>
          <button
            type="button"
            :disabled="listLoading || !!listError"
            :title="listError ? `Employees didn't load — Retry first` : undefined"
            class="px-3 py-1.5 bg-green-600 text-white rounded-lg hover:bg-green-700 transition text-xs md:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
            @click="openForm(null)"
          >
            + Add Employee
          </button>
        </div>
      </div>
    </div>

    <!-- No list yet: the first load (names, shifts and training together, so a
         dropdown never renders before its options), its failure, or an empty team.
         load() only runs then, so once there is a list nothing here replaces it — a
         failed save or refetch leaves it on screen. -->
    <div v-if="listLoading || !employees.length" class="card text-center py-6 text-sm">
      <p v-if="listLoading" class="text-gray-600">Loading employees…</p>
      <div v-else-if="listError" role="alert" class="space-y-2">
        <p class="text-red-700">Couldn't load employees: {{ listError }}</p>
        <button
          type="button"
          class="px-3 py-1.5 rounded-md border border-red-300 bg-white text-red-700 hover:bg-red-50 text-xs md:text-sm"
          @click="load"
        >Retry</button>
      </div>
      <p v-else class="text-gray-500">No employees yet — add one with “+ Add Employee”.</p>
    </div>

    <template v-else>
      <div class="card">
        <!-- A part that didn't load: say so above the matrix and keep the rest usable. -->
        <div
          v-if="trainingError"
          role="alert"
          class="mb-3 flex flex-wrap items-center justify-between gap-2 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
        >
          <span>Couldn't load training — the boxes stay off until it loads. <span class="text-red-600">({{ trainingError }})</span></span>
          <button
            type="button"
            :disabled="retryingTraining"
            class="rounded-md border border-red-300 bg-white px-2.5 py-1 text-xs font-medium text-red-700 hover:bg-red-50 disabled:opacity-50"
            @click="retryTraining"
          >{{ retryingTraining ? 'Loading…' : 'Retry' }}</button>
        </div>

        <div
          v-if="shiftsLoadError"
          role="alert"
          class="mb-3 flex flex-wrap items-center justify-between gap-2 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
        >
          <span>Couldn't load shifts — the shift dropdowns stay off until they load. <span class="text-red-600">({{ shiftsLoadError }})</span></span>
          <button
            type="button"
            :disabled="retryingShifts"
            class="rounded-md border border-red-300 bg-white px-2.5 py-1 text-xs font-medium text-red-700 hover:bg-red-50 disabled:opacity-50"
            @click="retryShifts"
          >{{ retryingShifts ? 'Loading…' : 'Retry' }}</button>
        </div>

        <p v-if="leavesError" role="alert" class="mb-3 text-xs text-amber-800">
          Couldn't load who's on leave, so the leave badges are missing ({{ leavesError }}).
          <button type="button" class="font-medium underline" @click="loadLeaves">Retry</button>
        </p>

        <p v-if="noMatches" class="text-center py-6 text-gray-500 text-sm">No employees match '{{ searchQuery.trim() }}'</p>
        <p v-else-if="!activeShown.length" class="text-center py-6 text-gray-500 text-sm">
          {{ query ? `No active employees match '${searchQuery.trim()}' — see Inactive employees below.` : 'No active employees. Reactivate someone below, or add one.' }}
        </p>

        <div class="space-y-2.5">
          <div
            v-for="employee in activeShown"
            :key="employee.id"
            :data-employee-id="employee.id"
            class="border-b border-gray-200 pb-2 last:border-b-0"
          >
            <div class="flex flex-wrap justify-between items-start gap-2 mb-2">
              <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
                <div class="flex items-center space-x-1.5">
                  <h3 class="text-sm md:text-base font-semibold text-gray-800">{{ fullName(employee) }}</h3>
                  <span v-if="employee.upi" class="text-xs text-gray-400 tabular-nums" title="UPI">#{{ employee.upi }}</span>
                  <span
                    v-if="leaveByEmployee.get(employee.id)"
                    class="rounded px-1.5 py-0.5 text-[10px] font-semibold"
                    :class="leaveState(leaveByEmployee.get(employee.id)!, today) === 'current' ? 'bg-violet-100 text-violet-800' : 'bg-gray-100 text-gray-600'"
                  >{{ leaveBadge(leaveByEmployee.get(employee.id)!, today) }}</span>
                </div>

                <!-- Shift: saves on pick. Stays enabled while saving — the newest pick wins. -->
                <div class="flex flex-wrap items-center gap-1.5">
                  <label :for="`${uid}-shift-${employee.id}`" class="text-xs md:text-sm text-gray-600">Shift:</label>
                  <select
                    :id="`${uid}-shift-${employee.id}`"
                    :value="shiftBoxes.draftOf(employee.id) ?? ''"
                    :disabled="!!shiftsLoadError"
                    :title="shiftsLoadError ? `Shifts didn't load — use Retry above` : undefined"
                    class="text-xs md:text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-1 focus:ring-blue-500 disabled:bg-gray-100"
                    @change="onShiftChange(employee.id, $event)"
                  >
                    <option value="">No shift</option>
                    <option v-if="offListShifts[employee.id]" :value="offListShifts[employee.id]?.id" disabled>
                      {{ offListShifts[employee.id]?.name }}
                    </option>
                    <option v-for="shift in activeShifts" :key="shift.id" :value="shift.id">
                      {{ shift.name }}
                    </option>
                  </select>
                  <UiSaveStatus
                    :state="shiftBoxes.stateOf(employee.id)"
                    :message="shiftBoxes.messageOf(employee.id)"
                    :label="`Shift for ${fullName(employee)}`"
                    :retryable="shiftBoxes.retryableOf(employee.id)"
                    undoable
                    @retry="shiftBoxes.retry(employee.id)"
                    @undo="shiftBoxes.undo(employee.id)"
                  />
                </div>
              </div>

              <div class="flex flex-wrap items-center gap-1.5">
                <UiSaveStatus
                  :state="trainingSaves.stateOf(employee.id)"
                  :message="trainingSaves.messageOf(employee.id)"
                  :label="`Training for ${fullName(employee)}`"
                  :retryable="trainingSaves.retryableOf(employee.id)"
                  undoable
                  @retry="trainingSaves.retry(employee.id)"
                  @undo="trainingSaves.undo(employee.id)"
                />
                <NuxtLink
                  :to="{ path: '/employee-overview', query: { employee: employee.id } }"
                  class="px-2.5 py-1 bg-gray-100 text-gray-600 rounded hover:bg-gray-200 transition text-xs md:text-sm"
                  title="Open this employee's overview"
                >
                  Overview
                </NuxtLink>
                <!-- Supervisors set leaves; a Team Lead can open one that exists, read-only. -->
                <button
                  v-if="canSetLeave || leaveByEmployee.get(employee.id)"
                  type="button"
                  class="px-2.5 py-1 bg-violet-50 text-violet-700 rounded hover:bg-violet-100 transition text-xs md:text-sm"
                  :title="`Leave of absence for ${fullName(employee)}`"
                  @click="openLeave(employee)"
                >
                  Leave
                </button>
                <button
                  type="button"
                  class="px-2.5 py-1 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition text-xs md:text-sm"
                  @click="openForm(employee)"
                >
                  Edit
                </button>
                <button
                  type="button"
                  :disabled="!!busyReason(employee.id)"
                  :title="busyReason(employee.id) || undefined"
                  class="px-2.5 py-1 bg-red-100 text-red-600 rounded hover:bg-red-200 transition text-xs md:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                  @click="openDelete(employee)"
                >
                  Delete
                </button>
              </div>
            </div>

            <!-- Training boxes: each click saves that one change. -->
            <div class="grid grid-cols-3 md:grid-cols-5 lg:grid-cols-6 xl:grid-cols-9 gap-1.5">
              <label
                v-for="jobFunction in gridJobs"
                :key="jobFunction.id"
                class="flex items-center space-x-1 p-1 rounded text-[11px] md:text-xs transition-colors"
                :class="trainingOpen(employee.id) ? 'cursor-pointer hover:bg-gray-50' : 'cursor-not-allowed opacity-60'"
              >
                <input
                  type="checkbox"
                  :data-employee-id="employee.id"
                  :data-job-function-id="jobFunction.id"
                  :aria-label="`${jobFunction.name} training for ${fullName(employee)}`"
                  :checked="isTrained(employee.id, jobFunction)"
                  :disabled="!trainingOpen(employee.id)"
                  class="w-3 h-3 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                  @change="onTrainingChange(employee.id, jobFunction, $event)"
                />
                <span
                  class="w-2.5 h-2.5 shrink-0 rounded border border-gray-300"
                  :style="{ backgroundColor: jobFunction.color_code }"
                  aria-hidden="true"
                ></span>
                <span class="text-[11px] md:text-xs text-gray-700 truncate">{{ jobFunction.name }}</span>
              </label>
            </div>
          </div>
        </div>

        <!-- Help line -->
        <div class="mt-3 pt-3 border-t border-gray-200 text-xs md:text-sm">
          <div class="flex items-center justify-center text-gray-500">
            <span class="inline-flex items-center">
              <svg class="w-3.5 h-3.5 mr-1 text-blue-500" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
                <path fill-rule="evenodd" d="M4 4a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2H4zm2 6a1 1 0 011-1h6a1 1 0 110 2H7a1 1 0 01-1-1zm1 3a1 1 0 100 2h6a1 1 0 100-2H7z" clip-rule="evenodd"></path>
              </svg>
              Tick a box to add that training, untick to remove it — each change saves as soon as you click.
            </span>
          </div>
        </div>
      </div>

      <!-- Inactive employees: kept (with their history) but out of the matrix. -->
      <div v-if="inactiveShown.length" ref="inactiveCard" class="card mt-3">
        <button
          type="button"
          :aria-expanded="inactiveOpen"
          :aria-controls="`${uid}-inactive`"
          class="flex w-full items-center justify-between text-left text-sm md:text-base font-semibold text-gray-700"
          @click="inactiveOpen = !inactiveOpen"
        >
          <span>Inactive employees ({{ inactiveShown.length }})</span>
          <svg
            class="h-4 w-4 text-gray-500 transition-transform"
            :class="inactiveOpen ? 'rotate-180' : ''"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
          </svg>
        </button>
        <ul v-show="inactiveOpen" :id="`${uid}-inactive`" class="mt-3 divide-y divide-gray-100">
          <li
            v-for="employee in inactiveShown"
            :key="employee.id"
            :data-employee-id="employee.id"
            class="flex flex-wrap items-center justify-between gap-2 py-2"
          >
            <div class="flex items-center gap-2 text-gray-500">
              <span class="text-sm font-medium">{{ fullName(employee) }}</span>
              <span v-if="employee.upi" class="text-xs text-gray-400 tabular-nums" title="UPI">#{{ employee.upi }}</span>
              <span class="rounded bg-gray-100 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-gray-500">Inactive</span>
            </div>
            <div class="flex flex-wrap items-center gap-1.5">
              <NuxtLink
                :to="{ path: '/employee-overview', query: { employee: employee.id } }"
                class="px-2.5 py-1 bg-gray-100 text-gray-600 rounded hover:bg-gray-200 transition text-xs md:text-sm"
                title="Open this employee's overview"
              >
                Overview
              </NuxtLink>
              <button
                type="button"
                :disabled="reactivating.has(employee.id)"
                class="px-2.5 py-1 bg-emerald-100 text-emerald-700 rounded hover:bg-emerald-200 transition text-xs md:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                @click="reactivate(employee)"
              >
                {{ reactivating.has(employee.id) ? 'Reactivating…' : 'Reactivate' }}
              </button>
              <button
                type="button"
                class="px-2.5 py-1 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition text-xs md:text-sm"
                @click="openForm(employee)"
              >
                Edit
              </button>
              <button
                type="button"
                :disabled="!!busyReason(employee.id)"
                :title="busyReason(employee.id) || undefined"
                class="px-2.5 py-1 bg-red-100 text-red-600 rounded hover:bg-red-200 transition text-xs md:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                @click="openDelete(employee)"
              >
                Delete
              </button>
            </div>
          </li>
        </ul>
      </div>
    </template>

    <!-- Add / Edit employee -->
    <UiModal
      v-if="formOpen"
      :title="editing ? 'Edit Employee' : 'Add Employee'"
      :busy="formSaving"
      @close="closeForm"
    >
      <form :id="`${uid}-form`" class="space-y-4" novalidate @submit.prevent="submitForm">
        <div>
          <label :for="`${uid}-first`" class="block text-sm font-medium text-gray-700 mb-1">First name</label>
          <input
            :id="`${uid}-first`"
            v-model="form.first_name"
            type="text"
            required
            maxlength="100"
            autocomplete="off"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label :for="`${uid}-last`" class="block text-sm font-medium text-gray-700 mb-1">Last name</label>
          <input
            :id="`${uid}-last`"
            v-model="form.last_name"
            type="text"
            required
            maxlength="100"
            autocomplete="off"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label :for="`${uid}-upi`" class="block text-sm font-medium text-gray-700 mb-1">UPI</label>
          <input
            :id="`${uid}-upi`"
            v-model="form.upi"
            type="text"
            inputmode="numeric"
            maxlength="20"
            autocomplete="off"
            placeholder="Numbers only"
            :aria-describedby="`${uid}-upi-help`"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <span :id="`${uid}-upi-help`" class="block text-xs text-gray-500 mt-1">The employee types this at the kiosk to check their own requests. Leave blank if they don't have one.</span>
        </div>

        <div class="flex items-center">
          <input
            :id="`${uid}-active`"
            v-model="form.is_active"
            type="checkbox"
            class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
          />
          <label :for="`${uid}-active`" class="ml-2 block text-sm text-gray-700">Active</label>
        </div>
        <p v-if="editing" class="-mt-3 pl-6 text-xs text-gray-500">
          Untick only when someone has left the team: they move to Inactive employees, out of the schedule.
          For time away, use <strong>Leave</strong> instead — it has dates and ends on its own.
        </p>

        <!-- Unticking Active on someone active: what deactivating leaves behind, before Save. -->
        <div v-if="deactivating" class="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
          <p v-if="formUsage.loading">Checking what deactivating affects…</p>
          <p v-else-if="formUsage.error">Couldn't check what deactivating affects ({{ formUsage.error }}). Deactivating keeps everything, so you can still save.</p>
          <template v-else>
            <p class="font-medium">If you deactivate {{ fullName(editing) }}:</p>
            <ul v-if="formUsage.notes.length" class="mt-1 list-disc space-y-0.5 pl-5">
              <li v-for="(note, i) in formUsage.notes" :key="i">{{ note }}</li>
            </ul>
            <p v-else class="mt-1">Everything is kept, and you can reactivate them later.</p>
            <template v-if="formUsage.blockers.length">
              <p class="mt-2 font-medium text-red-700">Can't deactivate yet:</p>
              <ul class="mt-1 list-disc space-y-0.5 pl-5 text-red-700">
                <li v-for="(blocker, i) in formUsage.blockers" :key="i">{{ blocker }}</li>
              </ul>
            </template>
          </template>
          <p v-if="busyReason(editing.id)" class="mt-2 font-medium text-red-700">{{ busyReason(editing.id) }} — deactivating waits until it's done.</p>
          <p v-if="canSetLeave" class="mt-2 border-t border-amber-200 pt-2">
            Going on leave rather than leaving the team?
            <button type="button" class="font-medium underline" @click="leaveInstead">Set a leave instead</button>
          </p>
        </div>

        <p v-if="formError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ formError }}</p>
      </form>

      <template #footer>
        <button
          type="button"
          :disabled="formSaving"
          class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          @click="closeForm"
        >Cancel</button>
        <button
          type="submit"
          :form="`${uid}-form`"
          :disabled="!canSubmit"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ formSaving ? 'Saving…' : editing ? 'Save' : 'Add Employee' }}</button>
      </template>
    </UiModal>

    <!-- Delete (or deactivate instead) -->
    <UiConfirmDialog
      v-if="del.employee"
      :title="`Delete ${fullName(del.employee)}?`"
      message="Deleting is permanent — it can't be undone."
      :loading="del.loading"
      confirm-label="Delete permanently"
      :busy-label="del.busy === 'delete' ? 'Deleting…' : 'Delete permanently'"
      danger
      :confirm-disabled="!del.usage || del.usage.blockers.length > 0 || !!busyReason(del.employee.id)"
      :secondary-label="del.employee.is_active ? (del.busy === 'deactivate' ? 'Deactivating…' : 'Deactivate instead') : undefined"
      :secondary-disabled="!!deactivateRefusal"
      :secondary-disabled-reason="deactivateRefusal || undefined"
      :busy="!!del.busy"
      :error="del.error || (del.loadError ? `Couldn't check what deleting would erase (${del.loadError}), so Delete stays off. Close and try again.` : '')"
      @confirm="confirmDelete"
      @secondary="deactivateInstead"
      @cancel="closeDelete"
    >
      <div v-if="del.usage && !del.loading" class="mt-3 space-y-3 text-sm text-gray-700">
        <div>
          <p class="font-medium text-gray-900">Delete permanently erases:</p>
          <ul v-if="del.usage.erases.length" class="mt-1 list-disc space-y-0.5 pl-5">
            <li v-for="(l, i) in del.usage.erases" :key="i">{{ line(l) }}</li>
          </ul>
          <p v-else class="mt-1">Nothing else — they have nothing else on record.</p>
        </div>
        <div v-if="del.usage.changes.length">
          <p class="font-medium text-gray-900">It also changes:</p>
          <ul class="mt-1 list-disc space-y-0.5 pl-5">
            <li v-for="(l, i) in del.usage.changes" :key="i">{{ line(l) }}</li>
          </ul>
        </div>
        <div v-if="del.usage.blockers.length" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-red-700">
          <p class="font-medium">Can't delete permanently:</p>
          <ul class="mt-1 list-disc space-y-0.5 pl-5">
            <li v-for="(l, i) in del.usage.blockers" :key="i">{{ line(l) }}</li>
          </ul>
          <p v-if="del.employee.is_active" class="mt-1">Deactivate them instead — that keeps everything.</p>
        </div>
        <div v-if="del.employee.is_active">
          <p class="font-medium text-gray-900">If you deactivate instead:</p>
          <ul v-if="del.usage.deactivate.notes.length" class="mt-1 list-disc space-y-0.5 pl-5">
            <li v-for="(l, i) in del.usage.deactivate.notes" :key="i">{{ line(l) }}</li>
          </ul>
          <p v-else class="mt-1">Everything is kept, and you can reactivate them later.</p>
          <template v-if="del.usage.deactivate.blockers.length">
            <p class="mt-2 font-medium text-red-700">Can't deactivate yet:</p>
            <ul class="mt-1 list-disc space-y-0.5 pl-5 text-red-700">
              <li v-for="(l, i) in del.usage.deactivate.blockers" :key="i">{{ line(l) }}</li>
            </ul>
          </template>
        </div>
      </div>
      <p v-if="busyReason(del.employee.id)" class="mt-3 text-sm font-medium text-amber-800">
        {{ busyReason(del.employee.id) }} — delete and deactivate wait until it's done.
      </p>
    </UiConfirmDialog>

    <!-- Leave of absence -->
    <TeamLeaveModal
      v-if="leaveFor"
      :employee="leaveFor"
      :start-with-form="leaveStartForm"
      @close="leaveFor = null"
      @changed="onLeaveChanged"
    />
  </div>
</template>

<script setup lang="ts">
import { toLocalISO, getTZISODate } from '~/utils/localDate'
import { canManageTeam } from '~/utils/roles'
import { leaveBadge, leaveState, leaveToShow, type LeaveDates } from '~/utils/leaveDisplay'

/** GET /api/employees/:id/usage (server/utils/deleteImpact.ts). */
interface ImpactLine { count: number; label: string }
interface Usage {
  name: string
  erases: ImpactLine[]
  changes: ImpactLine[]
  blockers: ImpactLine[]
  deactivate: { notes: ImpactLine[]; blockers: ImpactLine[] }
}
interface EmployeeFields { first_name: string; last_name: string; upi: string; is_active: boolean }

const {
  employees,
  error: employeesError,
  fetchEmployees,
  getAllEmployeeTraining,
  createEmployee,
  updateEmployee,
  deleteEmployee: deleteEmployeeApi,
} = useEmployees()
const { error: jobsError, fetchJobFunctions, getGroupedJobFunctions } = useJobFunctions()
const { shifts, error: shiftsError, fetchShifts } = useSchedule()
const toast = useToast()
const uid = useId()
const { user } = useAuth()
// Supervisors and up set leaves (server/api/leaves/* refuses anyone else).
const canSetLeave = computed(() => canManageTeam(user.value))
const today = computed(() => getTZISODate(user.value?.team_timezone || Intl.DateTimeFormat().resolvedOptions().timeZone))

const fullName = (e: { first_name: string; last_name: string }) => `${e.last_name}, ${e.first_name}`
const nameOf = (id: string) => {
  const e = employees.value.find((x) => x.id === id)
  return e ? fullName(e) : 'an employee'
}
/** A $fetch error's reason, for loads (the savers word their own failures). */
const reasonOf = (e: any): string => {
  const status = Number(e?.statusCode ?? e?.status ?? 0)
  return e?.data?.message || e?.statusMessage || (status ? `error ${status}` : "couldn't reach the server")
}
const line = (l: ImpactLine) => `${l.count.toLocaleString()} ${l.label}`
const fetchUsage = (id: string) =>
  $fetch<Usage>(`/api/employees/${id}/usage`, { params: { from: toLocalISO(new Date()) } })

// ── Savers ────────────────────────────────────────────────────────────────────

const trainingSaves = useTrainingSaves({ nameOf })

const shiftBoxes = useBoxSave<string>({
  namespace: 'employee-shift',
  label: (id) => `the shift for ${nameOf(id)}`,
  save: async (id, value) => {
    // $fetch itself, not updateEmployee: its error keeps the status, so Retry is
    // offered only where sending again could help (not for a shift deleted meanwhile).
    const saved = await $fetch<any>(`/api/employees/${id}`, { method: 'PUT', body: { shift_id: value || null } })
    // Patch just this row from the reply. A whole-list refetch per pick would land
    // on top of other rows' picks still in flight.
    employees.value = employees.value.map((e) => (e.id === id ? { ...e, ...saved } : e))
  },
})

// Every load or refetch feeds the boxes; init() leaves a box alone mid-edit or mid-save.
watch(employees, (list) => {
  for (const e of list) shiftBoxes.init(e.id, e.shift_id ?? '')
}, { immediate: true })

/**
 * Why this person can't be deleted or deactivated right now, or ''. A save still
 * out would fail under a delete; a failed one would lose its Retry / Undo with the
 * row. Inactive people have no boxes, so a failed save of theirs (deactivated from
 * another screen meanwhile) has no Retry / Undo to lose and doesn't block.
 */
const busyReason = (id: string): string => {
  const active = employees.value.find((e) => e.id === id)?.is_active !== false
  if (trainingSaves.pending(id)) {
    if (trainingSaves.stateOf(id) !== 'error') return 'Still saving training…'
    if (active) return "Training didn't save — Retry or Undo it first"
  }
  const shift = shiftBoxes.stateOf(id)
  if (shift === 'saving') return 'Still saving the shift…'
  if (shift === 'error' && active) return "The shift didn't save — Retry or Undo it first"
  return ''
}

/** Drop what's left of a failed save for someone deleted (else the leave guard keeps warning). */
const dropSaves = (id: string) => {
  trainingSaves.forget(id)
  shiftBoxes.undo(id)
}

// ── Loading ───────────────────────────────────────────────────────────────────

const listLoading = ref(true)
const listError = ref('')
const shiftsLoadError = ref('')
const retryingShifts = ref(false)
/** This visit's training load succeeded. Until then every box stays off. */
const trainingReady = ref(false)
const trainingError = ref('')
const retryingTraining = ref(false)

/** Job functions (the columns) and everyone's training; null (and trainingError set) if either failed. */
const fetchTraining = async (): Promise<Record<string, string[]> | null> => {
  try {
    const [, map] = await Promise.all([fetchJobFunctions(), getAllEmployeeTraining({ strict: true })])
    if (jobsError.value) throw { data: { message: jobsError.value } }
    return map
  } catch (e) {
    trainingError.value = reasonOf(e)
    return null
  }
}

const takeTraining = (map: Record<string, string[]> | null) => {
  if (!map) return
  // Everyone, inactive too: someone reactivated comes back with their boxes ready.
  trainingSaves.load(map, employees.value.map((e) => e.id))
  trainingError.value = ''
  trainingReady.value = true
}

const load = async () => {
  listLoading.value = true
  const training = fetchTraining()
  await Promise.all([fetchEmployees(false), fetchShifts({ includeInactive: true }), loadLeaves()])
  // These two don't throw; each composable keeps its failure in `error`.
  listError.value = employeesError.value ?? ''
  shiftsLoadError.value = shiftsError.value ?? ''
  const map = await training
  if (!listError.value) takeTraining(map)
  listLoading.value = false
}
onMounted(load)

let catchingUp = false
watch(employees, async (list) => {
  if (!trainingReady.value || catchingUp) return
  const missing = list.filter((e) => !trainingSaves.loaded(e.id)).map((e) => e.id)
  if (!missing.length) return
  catchingUp = true
  try {
    trainingSaves.load(await getAllEmployeeTraining({ strict: true }), missing)
  } catch (e) {
    toast.error(`Couldn't load training for ${missing.length === 1 ? nameOf(missing[0]!) : `${missing.length} people`}: ${reasonOf(e)}`)
  } finally {
    catchingUp = false
  }
})

const retryTraining = async () => {
  retryingTraining.value = true
  takeTraining(await fetchTraining())
  retryingTraining.value = false
}

const retryShifts = async () => {
  retryingShifts.value = true
  await fetchShifts()
  shiftsLoadError.value = shiftsError.value ?? ''
  retryingShifts.value = false
}

// ── Shift dropdown ────────────────────────────────────────────────────────────

const activeShifts = computed(() => shifts.value.filter((s) => s.is_active))

/**
 * Per employee: a saved shift that isn't one of the choices (it was deactivated),
 * listed as a disabled option so the dropdown shows what is really saved. Without
 * it the select showed a blank, as if the person had no shift.
 */
const offListShifts = computed(() => {
  const out: Record<string, { id: string; name: string }> = {}
  if (shiftsLoadError.value) return out // nothing to name them by; the dropdowns are off
  const byId = new Map(shifts.value.map((s) => [s.id, s]))
  for (const e of employees.value) {
    const id = shiftBoxes.savedOf(e.id)
    if (!id) continue
    const s = byId.get(id)
    if (s?.is_active) continue
    out[e.id] = { id, name: s ? `${s.name} (inactive)` : 'Unknown shift' }
  }
  return out
})

const onShiftChange = (id: string, e: Event) => {
  shiftBoxes.setDraft(id, (e.target as HTMLSelectElement).value)
  shiftBoxes.commit(id)
}

// ── Training boxes ────────────────────────────────────────────────────────────

const gridJobs = computed(() => getGroupedJobFunctions())

/**
 * The job ids one box stands for. The Meter box is the "Meter" parent itself when
 * there is one (a single training record); otherwise it's a stand-in group for
 * every "Meter N", ticked when any of them is.
 */
const idsFor = (jf: any): string[] => (jf._isGroup ? jf._meters.map((m: any) => m.id) : [jf.id])

const isTrained = (employeeId: string, jf: any) => {
  const want = trainingSaves.want(employeeId)
  return idsFor(jf).some((id) => want.includes(id))
}

const trainingOpen = (employeeId: string) => trainingReady.value && trainingSaves.loaded(employeeId)

const onTrainingChange = (employeeId: string, jf: any, e: Event) => {
  trainingSaves.toggle(employeeId, idsFor(jf), (e.target as HTMLInputElement).checked)
}

// ── Search and the two lists ──────────────────────────────────────────────────

const searchQuery = ref('')
const query = computed(() => searchQuery.value.trim().toLowerCase())

/** Name either way round ("mark smith", "smith, m") or UPI ("1555", "#1555"). */
const matches = (e: any) => {
  const q = query.value
  if (!q) return true
  const upi = q.replace(/^#/, '')
  return `${e.first_name} ${e.last_name}`.toLowerCase().includes(q)
    || fullName(e).toLowerCase().includes(q)
    || (!!upi && String(e.upi ?? '').includes(upi))
}

// Someone with a save out or failed stays on screen whatever the search, so the
// status and its Retry / Undo can't be filtered out of sight.
const activeShown = computed(() => employees.value.filter((e) => e.is_active && (matches(e) || !!busyReason(e.id))))
const inactiveShown = computed(() => employees.value.filter((e) => !e.is_active && matches(e)))
const noMatches = computed(() => !!query.value && !activeShown.value.length && !inactiveShown.value.length)

const inactiveOpen = ref(false)
// A search that finds inactive people opens their section — a match hidden in a
// collapsed list would read as "not found".
watch(query, (q) => { if (q && inactiveShown.value.length) inactiveOpen.value = true })

// Deactivated people move to that section at the bottom, folded shut. Below a long
// list it read as "they're gone and I can't get them back" — the header button and
// the save message both point at it now.
const inactiveCount = computed(() => employees.value.filter((e) => !e.is_active).length)
const inactiveCard = ref<HTMLElement | null>(null)
const showInactive = async () => {
  searchQuery.value = ''
  inactiveOpen.value = true
  await nextTick()
  inactiveCard.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}
const deactivatedMessage = (e: { first_name: string; last_name: string }) => {
  inactiveOpen.value = true
  return `Deactivated ${fullName(e)}. They're under Inactive employees at the bottom of this page, where Reactivate brings them back.`
}

// ── Leave of absence ──────────────────────────────────────────────────────────

/** Every leave running or still to come (GET /api/leaves), for the badges. */
const leaves = ref<(LeaveDates & { id: string; employee_id: string })[]>([])
const leavesError = ref('')
const loadLeaves = async () => {
  try {
    leaves.value = await $fetch('/api/leaves')
    leavesError.value = ''
  } catch (e) {
    leavesError.value = reasonOf(e)
  }
}
/** Per person: the leave running now, else the next one. */
const leaveByEmployee = computed(() => {
  const byPerson = new Map<string, typeof leaves.value>()
  for (const l of leaves.value) byPerson.set(l.employee_id, [...(byPerson.get(l.employee_id) ?? []), l])
  const out = new Map<string, LeaveDates>()
  for (const [id, list] of byPerson) {
    const shown = leaveToShow(list, today.value)
    if (shown) out.set(id, shown)
  }
  return out
})

const leaveFor = ref<any | null>(null)
const leaveStartForm = ref(false)
const openLeave = (employee: any, startWithForm = false) => {
  leaveStartForm.value = startWithForm
  leaveFor.value = employee
}
const onLeaveChanged = async (message: string) => {
  toast.success(message)
  await loadLeaves()
}
/** From the Edit window's deactivate warning: they're going on leave, not leaving. */
const leaveInstead = () => {
  const employee = editing.value
  closeForm()
  if (employee) openLeave(employee, true)
}

// ── Reactivate ────────────────────────────────────────────────────────────────

const reactivating = reactive(new Set<string>())

const reactivate = async (employee: any) => {
  if (reactivating.has(employee.id)) return
  reactivating.add(employee.id)
  const saved = await updateEmployee(employee.id, { is_active: true }, { refetch: false })
  reactivating.delete(employee.id)
  if (saved) toast.success(`Reactivated ${fullName(saved)}`)
  else toast.error(`Couldn't reactivate ${fullName(employee)}: ${employeesError.value || 'unknown error'}`)
}

// ── Add / Edit window ─────────────────────────────────────────────────────────

const NAME_MAX = 100
const blankFields = (): EmployeeFields => ({ first_name: '', last_name: '', upi: '', is_active: true })

const formOpen = ref(false)
const editing = ref<any | null>(null)
const form = reactive<EmployeeFields>(blankFields())
/** The fields as the window opened with them: an edit sends only what differs. */
const opened = ref<EmployeeFields>(blankFields())
const formSaving = ref(false)
const formError = ref('')
const formUsage = reactive({ loading: false, notes: [] as string[], blockers: [] as string[], error: '' })
let formUsageSeq = 0

const openForm = (employee: any | null) => {
  const fields: EmployeeFields = employee
    ? { first_name: employee.first_name, last_name: employee.last_name, upi: employee.upi ?? '', is_active: employee.is_active }
    : blankFields()
  editing.value = employee
  Object.assign(form, fields)
  opened.value = { ...fields }
  formError.value = ''
  formUsageSeq++
  Object.assign(formUsage, { loading: false, notes: [], blockers: [], error: '' })
  formOpen.value = true
}

const closeForm = () => {
  if (formSaving.value) return
  formOpen.value = false
  formUsageSeq++ // a usage reply still out has nowhere to go
}

/** Editing someone active, with the Active box now unticked. */
const deactivating = computed(() => !!editing.value && opened.value.is_active && !form.is_active)

// Unticking Active shows what deactivating leaves behind before Save, not after.
watch(deactivating, async (now) => {
  const mine = ++formUsageSeq
  Object.assign(formUsage, { loading: now, notes: [], blockers: [], error: '' })
  if (!now) return
  try {
    const usage = await fetchUsage(editing.value.id)
    if (mine !== formUsageSeq) return
    formUsage.notes = usage.deactivate.notes.map(line)
    formUsage.blockers = usage.deactivate.blockers.map(line)
  } catch (e) {
    if (mine === formUsageSeq) formUsage.error = reasonOf(e)
  } finally {
    if (mine === formUsageSeq) formUsage.loading = false
  }
})

const canSubmit = computed(() => {
  if (formSaving.value) return false
  if (!deactivating.value) return true
  return !formUsage.loading && !formUsage.blockers.length && !busyReason(editing.value.id)
})

const validationError = (first: string, last: string, upi: string): string => {
  if (!first || !last) return 'First and last name are both required.'
  if (first.length > NAME_MAX || last.length > NAME_MAX) return `Names can be at most ${NAME_MAX} characters.`
  if (upi && !/^\d{1,20}$/.test(upi)) return 'UPI must be numbers only (up to 20 digits), or left blank.'
  return ''
}

const submitForm = async () => {
  if (!canSubmit.value) return // Enter in a field submits even when the button is off
  const first = form.first_name.trim()
  const last = form.last_name.trim()
  const upi = form.upi.trim()
  formError.value = validationError(first, last, upi)
  if (formError.value) return

  const target = editing.value
  let body: Record<string, unknown> = { first_name: first, last_name: last, upi, is_active: form.is_active }
  if (target) {
    // Only what changed in this window: an untouched Active box (or name) must not
    // overwrite a change someone else saved after it opened.
    const was = opened.value
    body = {}
    if (form.first_name !== was.first_name) body.first_name = first
    if (form.last_name !== was.last_name) body.last_name = last
    if (form.upi !== was.upi) body.upi = upi
    if (form.is_active !== was.is_active) body.is_active = form.is_active
    if (!Object.keys(body).length) {
      closeForm()
      return
    }
  }

  formSaving.value = true
  // Both refetch the list themselves (in name order, inactive included).
  const saved: any = target ? await updateEmployee(target.id, body) : await createEmployee(body)
  formSaving.value = false
  if (!saved) {
    // The server's reason (a UPI already used by "Hang, Allen (inactive)", say) stays
    // in the window with what was typed.
    formError.value = employeesError.value || "Couldn't save the employee"
    return
  }
  // Someone new has no training: a known-empty baseline makes their boxes usable now.
  if (!target) trainingSaves.load({ [saved.id]: [] }, [saved.id])
  closeForm()
  toast.success(body.is_active === false && target ? deactivatedMessage(saved) : `${target ? 'Saved' : 'Added'} ${fullName(saved)}`)
}

// ── Delete / deactivate ───────────────────────────────────────────────────────

const del = reactive({
  employee: null as any,
  usage: null as Usage | null,
  loading: false,
  loadError: '',
  busy: '' as '' | 'delete' | 'deactivate',
  error: '',
})
let delSeq = 0

const openDelete = async (employee: any) => {
  const mine = ++delSeq
  Object.assign(del, { employee, usage: null, loading: true, loadError: '', busy: '', error: '' })
  try {
    const usage = await fetchUsage(employee.id)
    if (mine === delSeq) del.usage = usage
  } catch (e) {
    if (mine === delSeq) del.loadError = reasonOf(e)
  } finally {
    if (mine === delSeq) del.loading = false
  }
}

const closeDelete = () => {
  if (del.busy) return
  delSeq++
  del.employee = null
}

/** Why "Deactivate instead" is off, or ''. */
const deactivateRefusal = computed(() => {
  if (!del.employee) return ''
  const blockers = del.usage?.deactivate.blockers ?? []
  return busyReason(del.employee.id) || (blockers.length ? `Can't deactivate: ${blockers.map(line).join('; ')}` : '')
})

const confirmDelete = async () => {
  const employee = del.employee
  if (!employee || del.busy || !del.usage || del.usage.blockers.length || busyReason(employee.id)) return
  del.busy = 'delete'
  del.error = ''
  const ok = await deleteEmployeeApi(employee.id)
  del.busy = ''
  if (!ok) {
    del.error = employeesError.value || "Couldn't delete the employee"
    return
  }
  dropSaves(employee.id)
  del.employee = null
  toast.success(`Deleted ${fullName(employee)}`)
}

const deactivateInstead = async () => {
  const employee = del.employee
  if (!employee || del.busy || deactivateRefusal.value) return
  del.busy = 'deactivate'
  del.error = ''
  const saved = await updateEmployee(employee.id, { is_active: false }, { refetch: false })
  del.busy = ''
  if (!saved) {
    del.error = employeesError.value || "Couldn't deactivate the employee"
    return
  }
  del.employee = null
  toast.success(deactivatedMessage(employee))
}
</script>
