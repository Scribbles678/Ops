<template>
  <div class="details-page min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6 md:py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-5">
        <h1 class="text-2xl md:text-3xl font-semibold text-gray-800">Team Setup</h1>
        <NuxtLink to="/" class="btn-secondary">
          ← Back to Home
        </NuxtLink>
      </div>

      <!-- Tabs -->
      <div class="mb-5">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex flex-wrap gap-2 md:gap-4">
            <button
              @click="activeTab = 'employees'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'employees'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Employees &amp; Training
            </button>
            <button
              @click="activeTab = 'training-matrix'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'training-matrix'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Training Matrix
            </button>
            <button
              @click="activeTab = 'job-functions'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'job-functions'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Job Functions
            </button>
            <button
              @click="activeTab = 'shifts'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'shifts'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Shift Management
            </button>
            <button
              @click="activeTab = 'target-hours'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'target-hours'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Target Hours
            </button>
          </nav>
        </div>
      </div>

      <!-- Employees & Training tab. Its own component with its own cards, so it sits
           outside the shared card below. v-if (not v-show) on purpose: remounting
           refetches, so a job function added on the next tab shows up here. -->
      <TeamEmployeesTraining v-if="activeTab === 'employees'" />

      <!-- Training Matrix tab: trained people on shift per job per hour, against a
           per-job training target. Also its own card. -->
      <TeamTrainingMatrix v-else-if="activeTab === 'training-matrix'" />

      <!-- Tab Content -->
      <div v-else class="card">
        <!-- Job Functions Tab. Active jobs first, in their sort order, then inactive
             ones, greyed, so a deactivated job can be switched back on. -->
        <div v-if="activeTab === 'job-functions'">
          <div class="p-4 md:p-5">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl md:text-2xl font-semibold text-gray-800">Job Functions</h2>
              <button type="button" @click="openAddJob" class="btn-primary">
                + Add New Job Function
              </button>
            </div>

            <div v-if="jobsView === 'loading'" class="text-center py-6">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading job functions…</p>
            </div>

            <div v-else-if="jobsView === 'error'" role="alert" class="bg-red-50 border border-red-200 rounded-lg p-3 text-sm">
              <p class="text-red-700">Couldn't load job functions: {{ jobsLoadError }}</p>
              <button type="button" class="mt-2 font-medium text-red-700 underline" @click="loadJobs()">Retry</button>
            </div>

            <p v-else-if="jobsView === 'empty'" class="py-6 text-center text-gray-500">No job functions yet.</p>

            <div v-else class="space-y-3">
              <div
                v-for="jobFunction in orderedJobFunctions"
                :key="jobFunction.id"
                class="border border-gray-200 rounded-lg p-3 md:p-4 transition"
                :class="isActive(jobFunction) ? 'hover:shadow-md' : 'bg-gray-50'"
              >
                <div class="flex items-center justify-between gap-3">
                  <div class="flex items-center space-x-3 md:space-x-4 min-w-0">
                    <div
                      class="w-10 h-10 md:w-12 md:h-12 flex-shrink-0 rounded border border-gray-300"
                      :class="{ 'opacity-40': !isActive(jobFunction) }"
                      :style="{ backgroundColor: jobFunction.color_code }"
                    ></div>
                    <h3
                      class="text-base md:text-lg font-semibold flex flex-wrap items-center gap-2"
                      :class="isActive(jobFunction) ? 'text-gray-800' : 'text-gray-500'"
                    >
                      {{ jobFunction.name }}
                      <span
                        v-if="(jobFunction.staffing_priority ?? 3) !== 3"
                        :class="priorityBadgeClass(jobFunction.staffing_priority)"
                        class="px-1.5 py-0.5 rounded text-[11px] font-medium"
                      >{{ priorityLabel(jobFunction.staffing_priority) }}</span>
                      <span
                        v-if="!isActive(jobFunction)"
                        class="px-1.5 py-0.5 rounded text-[11px] font-medium bg-gray-200 text-gray-600"
                      >Inactive</span>
                    </h3>
                  </div>
                  <div class="flex flex-shrink-0 gap-2">
                    <button
                      v-if="!isActive(jobFunction)"
                      type="button"
                      :disabled="reactivating.has(`job:${jobFunction.id}`)"
                      @click="reactivate('job', jobFunction)"
                      class="px-3 py-1.5 text-sm bg-emerald-100 text-emerald-700 rounded hover:bg-emerald-200 transition disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {{ reactivating.has(`job:${jobFunction.id}`) ? 'Reactivating…' : 'Reactivate' }}
                    </button>
                    <button
                      type="button"
                      :aria-label="`Edit ${jobFunction.name}`"
                      @click="openEditJob(jobFunction)"
                      class="px-3 py-1.5 text-sm bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      :aria-label="`Delete ${jobFunction.name}`"
                      @click="openDelete('job', jobFunction)"
                      class="px-3 py-1.5 text-sm bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Shift Management Tab. Active shifts first, by start time, then inactive. -->
        <div v-else-if="activeTab === 'shifts'">
          <div class="p-4 md:p-5">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl md:text-2xl font-semibold text-gray-800">Shift Management</h2>
              <button type="button" @click="openAddShift" class="btn-primary">
                + Add New Shift
              </button>
            </div>

            <div v-if="shiftsView === 'loading'" class="text-center py-6">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading shifts…</p>
            </div>

            <div v-else-if="shiftsView === 'error'" role="alert" class="bg-red-50 border border-red-200 rounded-lg p-3 text-sm">
              <p class="text-red-700">Couldn't load shifts: {{ shiftsLoadError }}</p>
              <button type="button" class="mt-2 font-medium text-red-700 underline" @click="loadShifts()">Retry</button>
            </div>

            <p v-else-if="shiftsView === 'empty'" class="py-6 text-center text-gray-500">No shifts yet.</p>

            <div v-else class="space-y-3">
              <div
                v-for="shift in orderedShifts"
                :key="shift.id"
                class="border border-gray-200 rounded-lg p-3 md:p-4 transition"
                :class="isActive(shift) ? 'hover:shadow-md' : 'bg-gray-50'"
              >
                <div class="flex justify-between items-start gap-3">
                  <div class="flex-1 min-w-0" :class="isActive(shift) ? 'text-gray-700' : 'text-gray-500'">
                    <h3
                      class="text-base md:text-lg font-semibold mb-1 flex flex-wrap items-center gap-2"
                      :class="isActive(shift) ? 'text-gray-800' : 'text-gray-500'"
                    >
                      {{ shift.name }}
                      <span
                        v-if="!isActive(shift)"
                        class="px-1.5 py-0.5 rounded text-[11px] font-medium bg-gray-200 text-gray-600"
                      >Inactive</span>
                    </h3>
                    <p class="text-sm">{{ timeRange(shift.start_time, shift.end_time) }}</p>
                    <div v-if="shiftBreaks(shift).length" class="mt-1 flex flex-wrap gap-x-4 gap-y-1 text-xs">
                      <span v-for="b in shiftBreaks(shift)" :key="b.label">
                        <span class="font-medium">{{ b.label }}</span> {{ b.range }}
                      </span>
                    </div>
                  </div>
                  <div class="flex flex-shrink-0 gap-2">
                    <button
                      v-if="!isActive(shift)"
                      type="button"
                      :disabled="reactivating.has(`shift:${shift.id}`)"
                      @click="reactivate('shift', shift)"
                      class="px-3 py-1.5 text-sm bg-emerald-100 text-emerald-700 rounded hover:bg-emerald-200 transition disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {{ reactivating.has(`shift:${shift.id}`) ? 'Reactivating…' : 'Reactivate' }}
                    </button>
                    <button
                      type="button"
                      :aria-label="`Edit ${shift.name}`"
                      @click="openEditShift(shift)"
                      class="px-3 py-1.5 text-sm bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      :aria-label="`Delete ${shift.name}`"
                      @click="openDelete('shift', shift)"
                      class="px-3 py-1.5 text-sm bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Target Hours Tab. Active jobs only; each box saves on its own when you
             leave it (there used to be one Save Changes button for the whole table,
             and every job without a saved value showed — and then saved — 8.00). -->
        <div v-else-if="activeTab === 'target-hours'">
          <div class="p-4 md:p-5">
            <div class="mb-6">
              <h2 class="text-2xl font-bold text-gray-800">Target Hours</h2>
            </div>

            <div v-if="!targetHoursLoaded && !targetHoursLoadError" class="text-center py-8">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading target hours…</p>
            </div>

            <div v-else-if="!targetHoursLoaded" role="alert" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6 text-sm">
              <p class="text-red-700">Couldn't load target hours: {{ targetHoursLoadError }}</p>
              <button type="button" class="mt-2 font-medium text-red-700 underline" @click="loadTargetHours()">Retry</button>
            </div>

            <p v-else-if="!activeJobFunctions.length" class="py-6 text-center text-gray-500">
              No active job functions. Add one on the Job Functions tab.
            </p>

            <div v-else class="overflow-x-auto">
              <table class="w-full border-collapse">
                <thead>
                  <tr class="bg-gray-50">
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Job Function</th>
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Target Hours</th>
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Description</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="jobFunction in activeJobFunctions" :key="jobFunction.id">
                    <td class="border border-gray-200 px-4 py-3">
                      <div class="flex items-center space-x-3">
                        <div
                          class="w-4 h-4 rounded border border-gray-300"
                          :style="{ backgroundColor: jobFunction.color_code }"
                        ></div>
                        <span class="font-medium text-gray-800">{{ jobFunction.name }}</span>
                      </div>
                    </td>
                    <td class="border border-gray-200 px-4 py-3">
                      <div class="flex flex-wrap items-center gap-2">
                        <!-- Disabled only for a job added since the last load, until the
                             refetch gives it a box; typing there would go nowhere. -->
                        <input
                          :id="`target-hours-${jobFunction.id}`"
                          type="number"
                          min="0"
                          max="10000"
                          step="0.25"
                          inputmode="decimal"
                          :value="hoursTyping[jobFunction.id] ?? hoursText(jobFunction.id)"
                          :disabled="!targetBoxes.has(jobFunction.id)"
                          :placeholder="targetBoxes.has(jobFunction.id) ? 'not set' : '…'"
                          :aria-label="`${jobFunction.name} target hours`"
                          :aria-invalid="targetBoxes.stateOf(jobFunction.id) === 'error' || undefined"
                          class="w-24 px-2 py-1 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 disabled:bg-gray-100"
                          @input="onHoursInput(jobFunction.id, $event)"
                          @change="commitHours(jobFunction.id, $event)"
                          @blur="onHoursBlur(jobFunction.id)"
                        />
                        <UiSaveStatus
                          :state="targetBoxes.stateOf(jobFunction.id)"
                          :message="targetBoxes.messageOf(jobFunction.id)"
                          :label="`${jobFunction.name} target hours`"
                          :retryable="targetBoxes.retryableOf(jobFunction.id)"
                          undoable
                          @retry="targetBoxes.retry(jobFunction.id)"
                          @undo="undoHours(jobFunction.id)"
                        />
                      </div>
                    </td>
                    <td class="border border-gray-200 px-4 py-3">
                      <span class="text-sm text-gray-600">
                        Daily target hours for {{ jobFunction.name.toLowerCase() }} operations
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <!-- Help Text -->
            <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
              <h4 class="font-semibold text-blue-800 mb-2">About Target Hours</h4>
              <p class="text-sm text-blue-700">
                Target hours represent the ideal number of hours each job function should be staffed per day.
                These values are used to compare against actual scheduled hours in the schedule view.
              </p>
              <p class="text-sm text-blue-700 mt-2">
                Each value saves as soon as you leave its box (or press Enter). Enter hours in quarter hours,
                e.g. 7.75. A job with no value yet shows "not set".
              </p>
            </div>

          </div>
        </div>

      </div>
    </div>

    <!-- Job Function window. Only settings that change something. Productivity rate,
         unit, "exclude from targets grid" and the break/lunch coverage boxes were
         removed in Sep 2026: none of them changed what the builder did (see
         docs/SCHEDULE-BUILDER.md); their database columns stay, unread. -->
    <UiModal
      v-if="jobForm"
      :title="jobForm.id ? 'Edit Job Function' : 'Add New Job Function'"
      :busy="jobFormBusy"
      @close="closeJobForm"
    >
      <form id="job-function-form" novalidate class="space-y-4" @submit.prevent="submitJobForm">
        <div class="flex gap-3">
          <div class="flex-1">
            <label for="jobFunction_name" class="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input
              id="jobFunction_name"
              v-model="jobForm.name"
              type="text"
              required
              maxlength="100"
              autocomplete="off"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label for="jobFunction_color" class="block text-sm font-medium text-gray-700 mb-1">Color</label>
            <input
              id="jobFunction_color"
              v-model="jobForm.color_code"
              type="color"
              class="w-14 h-[42px] p-1 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>

        <!-- What the Automated Schedule Builder does with this job. -->
        <div class="space-y-4 border-t border-gray-200 pt-4">
          <p class="text-xs font-semibold uppercase tracking-wide text-gray-500">Schedule builder</p>
          <div>
            <label for="jobFunction_priority" class="block text-sm font-medium text-gray-700 mb-1">Staffing priority</label>
            <select
              id="jobFunction_priority"
              v-model.number="jobForm.staffing_priority"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option :value="1">1 — Critical (fill first)</option>
              <option :value="2">2 — High</option>
              <option :value="3">3 — Normal</option>
              <option :value="4">4 — Low</option>
              <option :value="5">5 — Optional (drop first)</option>
            </select>
            <p class="text-xs text-gray-500 mt-1">When there aren't enough people for every job, higher priorities are filled first.</p>
          </div>
          <div>
            <label for="jobFunction_max" class="block text-sm font-medium text-gray-700 mb-1">Max people at once</label>
            <input
              id="jobFunction_max"
              ref="maxHeadcountInput"
              v-model.number="jobForm.max_headcount"
              type="number"
              min="0"
              step="1"
              placeholder="No limit"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <p class="text-xs text-gray-500 mt-1">The builder stops adding people here at this number. Required assignments are placed regardless. Leave blank for no limit.</p>
          </div>
          <label for="jobFunction_surplus" class="flex items-start gap-2.5">
            <input
              id="jobFunction_surplus"
              v-model="jobForm.surplus_overflow"
              type="checkbox"
              class="mt-0.5 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <span class="text-sm font-medium text-gray-700">
              Send spare people here first
              <span class="block text-xs font-normal text-gray-500">Someone with spare time, whose jobs all have enough people, goes here before anywhere else (e.g. Pick, Projects).</span>
            </span>
          </label>
        </div>

        <!-- Edit only: a new job is always created active. -->
        <div v-if="jobForm.id" class="border-t border-gray-200 pt-4">
          <label for="jobFunction_active" class="flex items-start gap-2.5">
            <input
              id="jobFunction_active"
              v-model="jobForm.is_active"
              type="checkbox"
              class="mt-0.5 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <span class="text-sm font-medium text-gray-700">
              Active
              <span class="block text-xs font-normal text-gray-500">Inactive jobs are left out of the builder and the targets grid.</span>
            </span>
          </label>
          <!-- Unticked on an active job: what deactivating means, before Save. -->
          <div v-if="jobDeactivate.checking" class="mt-3 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm text-gray-700">
            <p v-if="jobDeactivate.loading" class="text-gray-500">Checking what deactivating affects…</p>
            <div v-else-if="jobDeactivate.error" role="alert">
              <p class="text-red-700">Couldn't check what deactivating affects: {{ jobDeactivate.error }}</p>
              <button type="button" class="mt-1 font-medium text-red-700 underline" @click="jobDeactivate.retry()">Retry</button>
            </div>
            <div v-else-if="jobDeactivate.blockers.length" role="alert">
              <p class="font-medium text-red-700">It can't be deactivated yet:</p>
              <ul class="mt-1 list-disc space-y-1 pl-5 text-red-700">
                <li v-for="(l, i) in jobDeactivate.blockers" :key="i">{{ l }}</li>
              </ul>
              <p class="mt-1">Tick Active again to save your other changes.</p>
            </div>
            <template v-else>
              <p>It's kept, with its history, and can be reactivated at any time.</p>
              <ul v-if="jobDeactivate.notes.length" class="mt-1 list-disc space-y-1 pl-5">
                <li v-for="(l, i) in jobDeactivate.notes" :key="i">{{ l }}</li>
              </ul>
            </template>
          </div>
        </div>

        <div v-if="jobFormError" role="alert" class="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          <p>{{ jobFormError }}</p>
          <button
            v-if="inactiveTwin && !jobForm.id"
            type="button"
            :disabled="jobFormBusy"
            class="mt-2 rounded-lg border border-red-300 bg-white px-3 py-1.5 font-medium text-red-700 hover:bg-red-50 disabled:opacity-50"
            @click="reactivateTwin"
          >{{ jobFormReactivating ? 'Reactivating…' : 'Reactivate it' }}</button>
        </div>
      </form>
      <template #footer>
        <button
          type="button"
          :disabled="jobFormBusy"
          class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          @click="closeJobForm"
        >Cancel</button>
        <button
          type="submit"
          form="job-function-form"
          :disabled="jobFormBusy || jobDeactivate.blockers.length > 0"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ jobFormSaving ? 'Saving…' : jobForm.id ? 'Update' : 'Create' }}</button>
      </template>
    </UiModal>

    <!-- Shift window -->
    <UiModal
      v-if="shiftForm"
      :title="shiftForm.id ? 'Edit Shift' : 'Add New Shift'"
      :busy="shiftFormSaving"
      size="lg"
      @close="closeShiftForm"
    >
      <form id="shift-form" novalidate class="space-y-4" @submit.prevent="submitShiftForm">
        <div>
          <label for="shift_name" class="block text-sm font-medium text-gray-700 mb-1">Shift Name</label>
          <input
            id="shift_name"
            v-model="shiftForm.name"
            type="text"
            required
            maxlength="100"
            autocomplete="off"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label for="shift_start" class="block text-sm font-medium text-gray-700 mb-1">Start Time</label>
            <input
              id="shift_start"
              v-model="shiftForm.start_time"
              type="time"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label for="shift_end" class="block text-sm font-medium text-gray-700 mb-1">End Time</label>
            <input
              id="shift_end"
              v-model="shiftForm.end_time"
              type="time"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>
        <div v-for="pair in SHIFT_PAIRS" :key="pair.label" class="grid grid-cols-2 gap-4">
          <div>
            <label :for="`shift_${pair.start}`" class="block text-sm font-medium text-gray-700 mb-1">{{ pair.label }} Start</label>
            <input
              :id="`shift_${pair.start}`"
              v-model="shiftForm[pair.start]"
              type="time"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label :for="`shift_${pair.end}`" class="block text-sm font-medium text-gray-700 mb-1">{{ pair.label }} End</label>
            <input
              :id="`shift_${pair.end}`"
              v-model="shiftForm[pair.end]"
              type="time"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>
        <p class="text-xs text-gray-500">Breaks and lunch are optional: fill in both times, or clear both.</p>

        <!-- Edit only: a new shift is always created active. -->
        <div v-if="shiftForm.id" class="border-t border-gray-200 pt-4">
          <label for="shift_active" class="flex items-start gap-2.5">
            <input
              id="shift_active"
              v-model="shiftForm.is_active"
              type="checkbox"
              class="mt-0.5 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <span class="text-sm font-medium text-gray-700">
              Active
              <span class="block text-xs font-normal text-gray-500">Inactive shifts are left out of the builder, the schedule and the display board.</span>
            </span>
          </label>
          <!-- Unticked on an active shift: what deactivating means, before Save. -->
          <div v-if="shiftDeactivate.checking" class="mt-3 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm text-gray-700">
            <p v-if="shiftDeactivate.loading" class="text-gray-500">Checking what deactivating affects…</p>
            <div v-else-if="shiftDeactivate.error" role="alert">
              <p class="text-red-700">Couldn't check what deactivating affects: {{ shiftDeactivate.error }}</p>
              <button type="button" class="mt-1 font-medium text-red-700 underline" @click="shiftDeactivate.retry()">Retry</button>
            </div>
            <div v-else-if="shiftDeactivate.blockers.length" role="alert">
              <p class="font-medium text-red-700">It can't be deactivated yet:</p>
              <ul class="mt-1 list-disc space-y-1 pl-5 text-red-700">
                <li v-for="(l, i) in shiftDeactivate.blockers" :key="i">{{ l }}</li>
              </ul>
              <p class="mt-1">Tick Active again to save your other changes.</p>
            </div>
            <template v-else>
              <p>It's kept, with its history, and can be reactivated at any time.</p>
              <ul v-if="shiftDeactivate.notes.length" class="mt-1 list-disc space-y-1 pl-5">
                <li v-for="(l, i) in shiftDeactivate.notes" :key="i">{{ l }}</li>
              </ul>
            </template>
          </div>
        </div>

        <p v-if="shiftFormError" role="alert" class="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {{ shiftFormError }}
        </p>
      </form>
      <template #footer>
        <button
          type="button"
          :disabled="shiftFormSaving"
          class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          @click="closeShiftForm"
        >Cancel</button>
        <button
          type="submit"
          form="shift-form"
          :disabled="shiftFormSaving || shiftDeactivate.blockers.length > 0"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ shiftFormSaving ? 'Saving…' : shiftForm.id ? 'Update' : 'Create' }}</button>
      </template>
    </UiModal>

    <!-- Delete window, for a job function or a shift. It says what "Delete permanently"
         would erase before anything happens, and offers Deactivate instead — the
         browser's confirm() could only ask "Are you sure?". -->
    <UiConfirmDialog
      v-if="delTarget"
      :title="`Delete ${delTarget.name}?`"
      message="Deleting permanently can't be undone."
      :loading="delLoading"
      confirm-label="Delete permanently"
      :busy-label="delBusy === 'delete' ? 'Deleting…' : 'Delete permanently'"
      danger
      :confirm-disabled="!delUsage || delLines.blockers.length > 0"
      :secondary-label="delTarget.isActive ? (delBusy === 'deactivate' ? 'Deactivating…' : 'Deactivate instead') : undefined"
      :secondary-disabled="delLines.deactivateBlockers.length > 0"
      :secondary-disabled-reason="delLines.deactivateBlockers.length ? `Can't be deactivated yet: ${delLines.deactivateBlockers.join('; ')}` : undefined"
      :busy="!!delBusy"
      :error="delError"
      @confirm="confirmDelete"
      @secondary="deactivateInstead"
      @cancel="closeDelete"
    >
      <div v-if="delLoadError" role="alert" class="mt-3 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
        Couldn't check what deleting would erase: {{ delLoadError }}. Delete permanently stays off until it can.
        <button type="button" class="ml-1 font-medium underline" @click="loadDeleteUsage()">Retry</button>
      </div>
      <div v-else-if="delUsage" class="mt-3 space-y-3 text-sm text-gray-700">
        <div v-if="delLines.blockers.length">
          <p class="font-medium text-red-700">It can't be deleted:</p>
          <ul class="mt-1 list-disc space-y-1 pl-5 text-red-700">
            <li v-for="(l, i) in delLines.blockers" :key="i">{{ l }}</li>
          </ul>
          <p class="mt-1 text-gray-600">
            {{ delTarget.isActive ? "Deactivate it instead: it's kept, with its history, but left out of scheduling." : "It's already inactive, which keeps it out of scheduling." }}
          </p>
        </div>
        <template v-else>
          <div v-if="delLines.erases.length">
            <p class="font-medium text-gray-800">Delete permanently erases:</p>
            <ul class="mt-1 list-disc space-y-1 pl-5">
              <li v-for="(l, i) in delLines.erases" :key="i">{{ l }}</li>
            </ul>
          </div>
          <div v-if="delLines.changes.length">
            <p class="font-medium text-gray-800">{{ delLines.erases.length ? 'And changes:' : 'Delete permanently changes:' }}</p>
            <ul class="mt-1 list-disc space-y-1 pl-5">
              <li v-for="(l, i) in delLines.changes" :key="i">{{ l }}</li>
            </ul>
          </div>
          <p v-if="!delLines.erases.length && !delLines.changes.length">Nothing else refers to it.</p>
        </template>

        <div v-if="delTarget.isActive" class="border-t border-gray-200 pt-3">
          <p class="font-medium text-gray-800">If you deactivate instead</p>
          <p class="text-gray-600">It's kept, with its history, and can be reactivated at any time.</p>
          <ul v-if="delLines.notes.length" class="mt-1 list-disc space-y-1 pl-5">
            <li v-for="(l, i) in delLines.notes" :key="i">{{ l }}</li>
          </ul>
          <template v-if="delLines.deactivateBlockers.length">
            <p class="mt-2 font-medium text-red-700">It can't be deactivated yet:</p>
            <ul class="mt-1 list-disc space-y-1 pl-5 text-red-700">
              <li v-for="(l, i) in delLines.deactivateBlockers" :key="i">{{ l }}</li>
            </ul>
          </template>
        </div>
      </div>
    </UiConfirmDialog>
  </div>
</template>

<script setup lang="ts">
import type { Ref } from 'vue'
import { toLocalISO } from '~/utils/localDate'

// The tab lives in the URL (?tab=…) so links can land on a specific one — the
// Rules & Targets page points at Shift Management and Training Matrix, /training
// redirects here — and the back button behaves.
type TeamSetupTab = 'employees' | 'training-matrix' | 'job-functions' | 'shifts' | 'target-hours'
const TABS: TeamSetupTab[] = ['employees', 'training-matrix', 'job-functions', 'shifts', 'target-hours']
const route = useRoute()
const router = useRouter()
const tabFromQuery = (): TeamSetupTab => {
  const t = String(route.query.tab ?? '')
  return (TABS as string[]).includes(t) ? (t as TeamSetupTab) : 'employees'
}
const activeTab = ref<TeamSetupTab>(tabFromQuery())
watch(activeTab, (tab) => {
  if (route.query.tab !== tab) router.replace({ query: { ...route.query, tab } })
})
watch(() => route.query.tab, () => { activeTab.value = tabFromQuery() })

// Every inline save on the page — the Target Hours boxes here and the child tabs'
// saves — holds a route change until it lands, and leaving with one still failed
// asks first. The savers outlive the tabs, so this one guard covers all of them.
useLeaveGuard()

const toast = useToast()

const {
  jobFunctions,
  error: jobFunctionsError,
  fetchJobFunctions,
  createJobFunction,
  updateJobFunction,
  deleteJobFunction
} = useJobFunctions()

const {
  shifts,
  error: shiftsError,
  fetchShifts,
  createShift,
  updateShift,
  deleteShift,
  fetchTargetHours
} = useSchedule()

// ---------------------------------------------------------------- shared helpers

interface ImpactLine { count: number; label: string }
interface Usage {
  name: string
  erases: ImpactLine[]
  changes: ImpactLine[]
  blockers: ImpactLine[]
  deactivate: { notes: ImpactLine[]; blockers: ImpactLine[] }
}

/** A $fetch error in words: the server's own message when it sent one. */
const reason = (e: any): string => e?.data?.message || e?.statusMessage || e?.message || 'unknown error'

/**
 * The composable's last error, cleared as it's read. Left set, it used to replace
 * the whole list with "Error loading …" after any failed save or delete.
 */
const takeError = (error: Ref<string | null>): string | null => {
  const message = error.value
  error.value = null
  return message
}

/** A save that worked but whose refetch didn't: say so, and keep the list shown. */
const toastRefreshFailure = (error: Ref<string | null>, what: string) => {
  const failed = takeError(error)
  if (failed) toast.error(`Couldn't refresh ${what}: ${failed}`)
}

/** What deleting or deactivating would do, counted from the viewer's own today. */
const fetchUsage = (api: 'job-functions' | 'shifts', id: string) =>
  $fetch<Usage>(`/api/${api}/${id}/usage`, { params: { from: toLocalISO(new Date()) } })
const impactLine = (l: ImpactLine) => `${l.count.toLocaleString()} ${l.label}`

const isActive = (row: any) => row.is_active !== false
const activeFirst = (rows: any[]) => [...rows.filter(isActive), ...rows.filter((r) => !isActive(r))]

type ListView = 'loading' | 'error' | 'empty' | 'list'

/**
 * One list's load. The spinner and the load error show only while there is no list:
 * every save refetches through the composable's shared `loading`, which used to blink
 * the whole list to a spinner, and a failed refresh of a list already on screen is a
 * toast instead. Overlapping calls share one request.
 */
const listLoader = (rows: Ref<any[]>, fetchRows: () => Promise<unknown>, error: Ref<string | null>, what: string) => {
  const loading = ref(false)
  const loaded = ref(false)
  const loadError = ref('')
  let inFlight: Promise<boolean> | null = null
  const load = (): Promise<boolean> => (inFlight ??= (async () => {
    loading.value = true
    try {
      await fetchRows()
      const failed = takeError(error)
      if (!failed) {
        loaded.value = true
        loadError.value = ''
        return true
      }
      if (loaded.value) toast.error(`Couldn't refresh ${what}: ${failed}`)
      else loadError.value = failed
      return false
    } finally {
      loading.value = false
      inFlight = null
    }
  })())
  const view = computed<ListView>(() => {
    if (rows.value.length) return 'list'
    if (loading.value || (!loaded.value && !loadError.value)) return 'loading'
    return loadError.value ? 'error' : 'empty'
  })
  return { load, loaded, loadError, view }
}

// ------------------------------------------------------------------------ lists

// include_inactive, remembered by the composables for their refetches after a save.
// (This used to call fetchJobFunctions(false), which it ignores, so an inactive job
// vanished from Team Setup and could never be switched back on.)
const {
  load: loadJobs,
  loaded: jobsLoaded,
  loadError: jobsLoadError,
  view: jobsView
} = listLoader(jobFunctions, () => fetchJobFunctions({ includeInactive: true }), jobFunctionsError, 'job functions')
const {
  load: loadShifts,
  loadError: shiftsLoadError,
  view: shiftsView
} = listLoader(shifts, () => fetchShifts({ includeInactive: true }), shiftsError, 'shifts')

const orderedJobFunctions = computed(() => activeFirst(jobFunctions.value))
const orderedShifts = computed(() => activeFirst(shifts.value))
const activeJobFunctions = computed(() => jobFunctions.value.filter(isActive))

const PRIORITY_LABELS: Record<number, string> = {
  1: 'Priority 1 · Critical',
  2: 'Priority 2 · High',
  4: 'Priority 4 · Low',
  5: 'Priority 5 · Optional'
}

const priorityLabel = (p: number | null | undefined) => PRIORITY_LABELS[p ?? 3] ?? ''

const priorityBadgeClass = (p: number | null | undefined) =>
  (p ?? 3) <= 2 ? 'bg-amber-100 text-amber-700' : 'bg-gray-100 text-gray-600'

/** "07:00:00" → "7:00 AM". */
const clockTime = (t: string | null | undefined): string => {
  if (!t) return ''
  const [h = 0, m = 0] = String(t).split(':').map(Number)
  return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`
}
const timeRange = (start: string | null | undefined, end: string | null | undefined) => `${clockTime(start)} – ${clockTime(end)}`

const SHIFT_PAIRS = [
  { label: 'Break 1', start: 'break_1_start', end: 'break_1_end' },
  { label: 'Break 2', start: 'break_2_start', end: 'break_2_end' },
  { label: 'Lunch', start: 'lunch_start', end: 'lunch_end' },
] as const

const shiftBreaks = (shift: any) =>
  SHIFT_PAIRS
    .filter((p) => shift[p.start] && shift[p.end])
    .map((p) => ({ label: p.label, range: timeRange(shift[p.start], shift[p.end]) }))

// ------------------------------------------------ switching on / off, deleting

const KINDS = {
  job: { api: 'job-functions', list: 'job functions', update: updateJobFunction, remove: deleteJobFunction, error: jobFunctionsError },
  shift: { api: 'shifts', list: 'shifts', update: updateShift, remove: deleteShift, error: shiftsError },
} as const
type Kind = keyof typeof KINDS

/** Switch a job function or shift on or off. '' when it worked, else the server's reason. */
const setActive = async (kind: Kind, id: string, active: boolean): Promise<string> => {
  const k = KINDS[kind]
  if (!(await k.update(id, { is_active: active }))) return takeError(k.error) || 'unknown error'
  toastRefreshFailure(k.error, k.list)
  if (kind === 'job' && !active) dropTargetBox(id)
  return ''
}

// "job:<id>" / "shift:<id>" while its Reactivate request is out.
const reactivating = reactive(new Set<string>())

const reactivate = async (kind: Kind, row: any) => {
  const key = `${kind}:${row.id}`
  if (reactivating.has(key)) return
  reactivating.add(key)
  const failed = await setActive(kind, row.id, true)
  reactivating.delete(key)
  if (failed) toast.error(`Couldn't reactivate ${row.name}: ${failed}`)
  else toast.success(`Reactivated ${row.name}`)
}

/**
 * For an edit window: while `target()` names an item whose Active box was just
 * unticked, what deactivating it would mean (notes) or why it can't be (blockers).
 */
const deactivateCheck = (api: 'job-functions' | 'shifts', target: () => string | null) => {
  let seq = 0
  const run = async (id: string | null) => {
    const mine = ++seq
    Object.assign(state, { checking: !!id, loading: !!id, error: '', notes: [], blockers: [] })
    if (!id) return
    try {
      const usage = await fetchUsage(api, id)
      if (mine !== seq) return
      state.notes = usage.deactivate.notes.map(impactLine)
      state.blockers = usage.deactivate.blockers.map(impactLine)
    } catch (e) {
      if (mine === seq) state.error = reason(e)
    } finally {
      if (mine === seq) state.loading = false
    }
  }
  const state = reactive({
    checking: false, loading: false, error: '', notes: [] as string[], blockers: [] as string[],
    retry: () => run(target()),
  })
  watch(target, run)
  return state
}

// The delete window.
const delTarget = ref<{ kind: Kind; id: string; name: string; isActive: boolean } | null>(null)
const delUsage = ref<Usage | null>(null)
const delLoading = ref(false)
const delLoadError = ref('')
const delBusy = ref<'' | 'delete' | 'deactivate'>('')
const delError = ref('')
let delSeq = 0

const delLines = computed(() => {
  const u = delUsage.value
  return {
    erases: u?.erases.map(impactLine) ?? [],
    changes: u?.changes.map(impactLine) ?? [],
    blockers: u?.blockers.map(impactLine) ?? [],
    notes: u?.deactivate.notes.map(impactLine) ?? [],
    deactivateBlockers: u?.deactivate.blockers.map(impactLine) ?? [],
  }
})

const loadDeleteUsage = async () => {
  const t = delTarget.value
  if (!t) return
  const mine = ++delSeq
  delUsage.value = null
  delLoadError.value = ''
  delLoading.value = true
  try {
    const usage = await fetchUsage(KINDS[t.kind].api, t.id)
    if (mine === delSeq) delUsage.value = usage
  } catch (e) {
    if (mine === delSeq) delLoadError.value = reason(e)
  } finally {
    if (mine === delSeq) delLoading.value = false
  }
}

const openDelete = (kind: Kind, row: any) => {
  delTarget.value = { kind, id: row.id, name: row.name, isActive: isActive(row) }
  delError.value = ''
  loadDeleteUsage()
}

const closeDelete = () => {
  if (delBusy.value) return
  delSeq++ // a usage reply still on its way is for a window that's gone
  delTarget.value = null
}

const confirmDelete = async () => {
  const t = delTarget.value
  if (!t || delBusy.value) return
  const k = KINDS[t.kind]
  delBusy.value = 'delete'
  delError.value = ''
  const ok = await k.remove(t.id)
  delBusy.value = ''
  if (!ok) {
    delError.value = takeError(k.error) || "Couldn't delete"
    return
  }
  toastRefreshFailure(k.error, k.list)
  if (t.kind === 'job') dropTargetBox(t.id)
  closeDelete()
  toast.success(`Deleted ${t.name}`)
}

const deactivateInstead = async () => {
  const t = delTarget.value
  if (!t || delBusy.value) return
  delBusy.value = 'deactivate'
  delError.value = ''
  const failed = await setActive(t.kind, t.id, false)
  delBusy.value = ''
  if (failed) {
    delError.value = failed
    return
  }
  closeDelete()
  toast.success(`Deactivated ${t.name}`)
}

// ---------------------------------------------------------- job function window

interface JobForm {
  id: string | null // null while adding
  wasActive: boolean
  name: string
  color_code: string
  staffing_priority: number
  max_headcount: number | '' | null // v-model.number leaves a cleared box as ''
  surplus_overflow: boolean
  is_active: boolean
}
const jobForm = ref<JobForm | null>(null)
const jobFormSaving = ref(false)
const jobFormReactivating = ref(false)
const jobFormBusy = computed(() => jobFormSaving.value || jobFormReactivating.value)
const jobFormError = ref('')
// The name the server said an inactive job already has (see inactiveTwin).
const jobFormTwinName = ref('')
const maxHeadcountInput = ref<HTMLInputElement | null>(null)

const jobDeactivate = deactivateCheck('job-functions', () => {
  const f = jobForm.value
  return f?.id && f.wasActive && !f.is_active ? f.id : null
})

// rethrowJobFunctionError's 409 when the name belongs to a deactivated job.
const INACTIVE_TWIN = /^An inactive job function named "/

/** The inactive job the server said already has this name, when the list has it. */
const inactiveTwin = computed(() =>
  jobFormTwinName.value
    ? jobFunctions.value.find((j) => !isActive(j) && j.name === jobFormTwinName.value) ?? null
    : null
)

// Typing another name makes that answer stale; don't offer to reactivate a job
// that's no longer what's in the box.
watch(() => jobForm.value?.name.trim(), (name) => {
  if (jobFormTwinName.value && name !== jobFormTwinName.value) {
    jobFormTwinName.value = ''
    jobFormError.value = ''
  }
})

const openJobForm = (form: JobForm) => {
  jobFormError.value = ''
  jobFormTwinName.value = ''
  jobForm.value = form
}

const openAddJob = () => openJobForm({
  id: null,
  wasActive: true,
  name: '',
  color_code: '#3B82F6',
  staffing_priority: 3,
  max_headcount: null,
  surplus_overflow: false,
  is_active: true
})

const openEditJob = (jobFunction: any) => openJobForm({
  id: jobFunction.id,
  wasActive: isActive(jobFunction),
  name: jobFunction.name,
  color_code: jobFunction.color_code,
  staffing_priority: jobFunction.staffing_priority ?? 3,
  max_headcount: jobFunction.max_headcount ?? null,
  surplus_overflow: jobFunction.surplus_overflow ?? false,
  is_active: isActive(jobFunction)
})

const closeJobForm = () => {
  if (jobFormBusy.value) return
  jobForm.value = null
}

// The form sends only the fields it shows. The update route leaves anything not
// sent as it is, so the retired columns keep whatever they held.
const submitJobForm = async () => {
  const f = jobForm.value
  if (!f || jobFormBusy.value || jobDeactivate.blockers.length) return
  jobFormError.value = ''
  jobFormTwinName.value = ''

  const name = f.name.trim()
  if (!name) {
    jobFormError.value = 'Enter a name.'
    return
  }
  const max = f.max_headcount === '' || f.max_headcount == null ? null : Number(f.max_headcount)
  // badInput: the browser holds text it can't read as a number and reports '' — that
  // must not save as "no limit".
  if (maxHeadcountInput.value?.validity.badInput || (max !== null && !(Number.isInteger(max) && max >= 0))) {
    jobFormError.value = '"Max people at once" must be a whole number, 0 or more (or blank for no limit).'
    return
  }

  const body: Record<string, unknown> = {
    name,
    color_code: f.color_code,
    staffing_priority: f.staffing_priority,
    max_headcount: max,
    surplus_overflow: f.surplus_overflow
  }
  if (f.id) body.is_active = f.is_active
  // Last in the list. A count of the list (the old default) can collide now that
  // inactive jobs are in it too.
  else body.sort_order = jobFunctions.value.reduce((m, j) => Math.max(m, Number(j.sort_order) || 0), -1) + 1

  jobFormSaving.value = true
  const saved = f.id ? await updateJobFunction(f.id, body) : await createJobFunction(body)
  jobFormSaving.value = false
  if (!saved) {
    jobFormError.value = takeError(jobFunctionsError) || "Couldn't save"
    // Renaming onto a deactivated job's name: reactivating that one would throw away
    // this edit, so just ask for another name.
    if (f.id && INACTIVE_TWIN.test(jobFormError.value)) {
      jobFormError.value = `An inactive job function is already named "${name}". Pick another name.`
    } else if (INACTIVE_TWIN.test(jobFormError.value)) {
      jobFormTwinName.value = name
      // Deactivated from another session, so not in this list yet: fetch it.
      if (!inactiveTwin.value) loadJobs()
    }
    return
  }
  toastRefreshFailure(jobFunctionsError, 'job functions')
  if (f.id && f.wasActive && !f.is_active) dropTargetBox(f.id)
  jobForm.value = null
  toast.success(`${f.id ? 'Saved' : 'Added'} ${name}`)
}

const reactivateTwin = async () => {
  const twin = inactiveTwin.value
  if (!twin || jobFormBusy.value) return
  jobFormReactivating.value = true
  const failed = await setActive('job', twin.id, true)
  jobFormReactivating.value = false
  if (failed) {
    jobFormError.value = `Couldn't reactivate ${twin.name}: ${failed}`
    return
  }
  jobForm.value = null
  toast.success(`Reactivated ${twin.name}`)
}

// ------------------------------------------------------------------ shift window

interface ShiftForm {
  id: string | null // null while adding
  wasActive: boolean
  name: string
  start_time: string
  end_time: string
  break_1_start: string
  break_1_end: string
  break_2_start: string
  break_2_end: string
  lunch_start: string
  lunch_end: string
  is_active: boolean
}
const shiftForm = ref<ShiftForm | null>(null)
const shiftFormSaving = ref(false)
const shiftFormError = ref('')

const shiftDeactivate = deactivateCheck('shifts', () => {
  const f = shiftForm.value
  return f?.id && f.wasActive && !f.is_active ? f.id : null
})

/** "07:00:00" → "07:00", the time box's own format; null → '' (no time). */
const hhmm = (t: string | null | undefined) => (t ? String(t).slice(0, 5) : '')

const openShiftForm = (form: ShiftForm) => {
  shiftFormError.value = ''
  shiftForm.value = form
}

const openAddShift = () => openShiftForm({
  id: null,
  wasActive: true,
  name: '',
  start_time: '',
  end_time: '',
  break_1_start: '',
  break_1_end: '',
  break_2_start: '',
  break_2_end: '',
  lunch_start: '',
  lunch_end: '',
  is_active: true
})

const openEditShift = (shift: any) => openShiftForm({
  id: shift.id,
  wasActive: isActive(shift),
  name: shift.name,
  start_time: hhmm(shift.start_time),
  end_time: hhmm(shift.end_time),
  break_1_start: hhmm(shift.break_1_start),
  break_1_end: hhmm(shift.break_1_end),
  break_2_start: hhmm(shift.break_2_start),
  break_2_end: hhmm(shift.break_2_end),
  lunch_start: hhmm(shift.lunch_start),
  lunch_end: hhmm(shift.lunch_end),
  is_active: isActive(shift)
})

const closeShiftForm = () => {
  if (shiftFormSaving.value) return
  shiftForm.value = null
}

/**
 * What's wrong with the form, in words, or ''. The server holds the same rules
 * (server/utils/shiftInput.ts) and still has the last word. Times compare as
 * "HH:MM" strings, which sort in clock order.
 */
const shiftProblem = (f: ShiftForm): string => {
  if (!f.name.trim()) return 'Enter a shift name.'
  const start = hhmm(f.start_time)
  const end = hhmm(f.end_time)
  if (!start || !end) return 'A shift needs a start time and an end time.'
  // Same day only, as the server (server/utils/shiftInput.ts): no site runs one, and
  // an overnight shift lost its hours on save.
  if (end <= start) return "A shift must end after it starts — overnight shifts aren't supported."
  for (const p of SHIFT_PAIRS) {
    const s = hhmm(f[p.start])
    const e = hhmm(f[p.end])
    if (!s && !e) continue
    if (!s || !e) return `${p.label} needs both a start and an end time (or neither).`
    if (e <= s) return `${p.label} must end after it starts.`
    if (s < start || e > end) return `${p.label} must fall within the shift (${timeRange(start, end)}).`
  }
  return ''
}

const submitShiftForm = async () => {
  const f = shiftForm.value
  if (!f || shiftFormSaving.value || shiftDeactivate.blockers.length) return
  shiftFormError.value = shiftProblem(f)
  if (shiftFormError.value) return

  // A cleared time box is '' and goes as it is: the server reads '' as no time.
  const name = f.name.trim()
  const body: Record<string, unknown> = { name, start_time: f.start_time, end_time: f.end_time }
  for (const p of SHIFT_PAIRS) {
    body[p.start] = f[p.start]
    body[p.end] = f[p.end]
  }
  if (f.id) body.is_active = f.is_active

  shiftFormSaving.value = true
  const saved = f.id ? await updateShift(f.id, body) : await createShift(body)
  shiftFormSaving.value = false
  if (!saved) {
    // The old form closed as if it had saved and only logged the error.
    shiftFormError.value = takeError(shiftsError) || "Couldn't save"
    return
  }
  toastRefreshFailure(shiftsError, 'shifts')
  shiftForm.value = null
  toast.success(`${f.id ? 'Saved' : 'Added'} ${name}`)
}

// ------------------------------------------------------------------ target hours

const MAX_TARGET_HOURS = 10000 // as server/api/target-hours/index.post.ts
const HOURS_HINT = 'Enter hours from 0 to 10,000, in quarter hours (e.g. 7.75)'
const isQuarterHours = (n: unknown): n is number =>
  typeof n === 'number' && Number.isFinite(n) && n >= 0 && n <= MAX_TARGET_HOURS && Number.isInteger(n * 4)

/** A refusal shaped like a $fetch 400, so the box shows it and offers no Retry. */
const refused = (message: string) => Object.assign(new Error(message), { statusCode: 400, data: { message } })

// One box per active job: value = hours, null = not set. The store outlives this
// page, so a save still out when the tab or page changes is finished, not lost.
const targetBoxes = useBoxSave<number | null>({
  namespace: 'target-hours',
  label: (id) => `${jobFunctions.value.find((j) => j.id === id)?.name ?? 'Job'} target hours`,
  save: async (id, hours) => {
    // commitHours never commits a bad value; this is the last line if one ever did.
    if (!isQuarterHours(hours)) throw refused(HOURS_HINT)
    await $fetch('/api/target-hours', {
      method: 'POST',
      body: { items: [{ job_function_id: id, target_hours: hours }] }
    })
  }
})

const hoursText = (id: string) => {
  const v = targetBoxes.draftOf(id)
  return v == null ? '' : String(v)
}

// What's in a box while it's being typed in. Vue puts every box's bound value back
// whenever the page re-renders — which any row's "Saving…" / "Saved" does — so
// without this, one row's save landing wiped what was half-typed in the next.
const hoursTyping = reactive<Record<string, string>>({})
const onHoursInput = (id: string, e: Event) => { hoursTyping[id] = (e.target as HTMLInputElement).value }
const onHoursBlur = (id: string) => { delete hoursTyping[id] }

const commitHours = (id: string, e: Event) => {
  const el = e.target as HTMLInputElement
  delete hoursTyping[id]
  const raw = el.value.trim()
  // A number box reports '' for text it can't read ("1e"), so badInput tells that
  // apart from a box that was really cleared.
  const hours = raw === '' || el.validity.badInput ? null : Number(raw)
  targetBoxes.setDraft(id, hours)
  // Emptied a box that was never set: nothing to save (and nothing to refuse).
  if (hours === null && !el.validity.badInput && targetBoxes.savedOf(id) == null) {
    targetBoxes.commit(id)
    return
  }
  if (!isQuarterHours(hours)) {
    targetBoxes.invalid(id, HOURS_HINT)
    return
  }
  targetBoxes.commit(id)
}

const undoHours = (id: string) => {
  targetBoxes.undo(id)
  // Text the box couldn't read ("1e") reads back as '', the same as "not set", so
  // Vue sees nothing to repaint; put the saved value back by hand.
  const el = document.getElementById(`target-hours-${id}`) as HTMLInputElement | null
  if (el) el.value = hoursText(id)
}

// A job leaving this table (deactivated or deleted) takes a refused value in its
// box with it; otherwise the leave guard would keep warning about a box nobody can
// see any more.
const dropTargetBox = (id: string) => {
  if (targetBoxes.stateOf(id) === 'error') targetBoxes.undo(id)
}

const targetHoursLoaded = ref(false)
const targetHoursLoadError = ref('')
let targetHoursSeq = 0
// The last values loaded, for jobs that join the table later.
let lastTargetHours: Record<string, number> = {}

/**
 * Strict: a failed load must not look like "nothing set" (it used to fill every box
 * with 8.00, which Save Changes then wrote over the real values). Refetched each
 * time the tab opens; boxes mid-edit or mid-save keep what's in them (init).
 */
const loadTargetHours = async () => {
  const mine = ++targetHoursSeq
  // Before the first load, a Retry goes back to "Loading target hours…".
  if (!targetHoursLoaded.value) targetHoursLoadError.value = ''
  try {
    // The rows are the active jobs, so they have to be in first — landing straight
    // on ?tab=target-hours starts both loads together.
    const [saved, jobsOk] = await Promise.all([
      fetchTargetHours({ strict: true }),
      jobsLoaded.value ? true : loadJobs()
    ])
    if (!jobsOk) throw new Error(`couldn't load job functions (${jobsLoadError.value || 'unknown error'})`)
    if (mine !== targetHoursSeq) return
    lastTargetHours = saved
    for (const jf of activeJobFunctions.value) targetBoxes.init(jf.id, saved[jf.id] ?? null)
    targetHoursLoaded.value = true
    targetHoursLoadError.value = ''
  } catch (e) {
    if (mine !== targetHoursSeq) return
    if (targetHoursLoaded.value) toast.error(`Couldn't refresh target hours: ${reason(e)}`)
    else targetHoursLoadError.value = reason(e)
  }
}

// ------------------------------------------------------------------------- load

onMounted(() => {
  loadJobs()
  loadShifts()
  // Landing straight on Target Hours (?tab=target-hours) skips the tab watcher.
  if (activeTab.value === 'target-hours') loadTargetHours()
})

// A job added or reactivated after the load gets its box straight away, with the
// value it had (none for a new job) — not a disabled box until the next refetch.
watch(activeJobFunctions, (jobs) => {
  if (!targetHoursLoaded.value) return
  for (const jf of jobs) if (!targetBoxes.has(jf.id)) targetBoxes.init(jf.id, lastTargetHours[jf.id] ?? null)
})

// Load per-tab data on demand
watch(activeTab, (newTab) => {
  // A box removed mid-typing: Chromium fires its change first (so it saves, as if
  // left). A browser that doesn't would bring the unsent text back as if it were
  // the value.
  for (const id of Object.keys(hoursTyping)) delete hoursTyping[id]
  if (newTab === 'target-hours') loadTargetHours()
})
</script>
