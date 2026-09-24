<template>
  <div class="min-h-screen bg-gray-50">
    <div class="px-3 py-2">
      <!-- Header -->
      <div class="flex items-center justify-between mb-2">
        <div class="flex flex-col">
          <h1 class="text-2xl font-bold text-gray-800">View/Edit Schedule</h1>
          <p class="text-gray-600 mt-0.5 text-sm">
            <ClientOnly>
              {{ formatDate(scheduleDate || '') }}
            </ClientOnly>
          </p>
          <!-- KPI strip under title -->
          <div class="hidden md:flex gap-1.5 mt-1.5">
            <div class="rounded border border-gray-200 bg-white px-2 py-1 text-center">
              <div class="text-xs font-bold text-blue-600">{{ totalEmployees }}</div>
              <div class="text-[10px] text-gray-600" title="People on a shift today who aren't off for all of it">Employees</div>
            </div>
            <div class="rounded border border-gray-200 bg-white px-2 py-1 text-center">
              <div class="text-xs font-bold text-green-600">{{ fmtHours(laborHoursAvailable) }}h</div>
              <div
                class="text-[10px] text-gray-600"
                title="Hours people are on the floor today: their shift minus lunch, breaks and time off"
              >Labor Hours Available</div>
            </div>
            <div class="rounded border border-gray-200 bg-white px-2 py-1 text-center">
              <div class="text-xs font-bold text-purple-600">{{ totalShifts }}</div>
              <div class="text-[10px] text-gray-600">Active Shifts</div>
            </div>
            <div class="rounded border border-gray-200 bg-white px-2 py-1 text-center">
              <div class="text-xs font-bold text-orange-600">{{ unassignedEmployees }}</div>
              <div class="text-[10px] text-gray-600" title="Working today with nothing assigned yet">Unassigned</div>
            </div>
            <div class="rounded border border-gray-200 bg-white px-2 py-1 text-center">
              <div class="text-xs font-bold text-red-600">{{ ptoUsed ? fmtHours(ptoUsed.used) : '—' }}</div>
              <div
                class="text-[10px] text-gray-600"
                :title="ptoUsed?.cap ? `Paid hours off today, of the ${fmtHours(ptoUsed.cap)}h daily PTO cap` : 'Paid hours off today'"
              >PTO Hours</div>
            </div>
          </div>
        </div>
        <div class="flex space-x-2">
          <button 
            @click="saveSchedule()"
            :disabled="isSaving"
            class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed flex items-center text-sm px-3 py-1.5"
          >
            <svg v-if="isSaving" class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {{ isSaving ? 'Saving...' : 'Save Schedule' }}
          </button>
          <button
            @click="showExportModal = true"
            class="btn-secondary text-sm px-3 py-1.5 flex items-center"
            title="Download any historical schedule as CSV"
          >
            Export CSV
          </button>
          <NuxtLink to="/" class="btn-secondary text-sm px-3 py-1.5">
            ← Back to Home
          </NuxtLink>
        </div>
      </div>

      <!-- Date Selector and Job Function Breakdown Row -->
      <div class="flex gap-3 mb-2 items-stretch">
        <!-- Date Selector (Left Side) -->
        <div class="card flex-shrink-0 h-full" style="width: 320px;">
          <div class="p-2.5">
            <h2 class="text-base font-bold text-gray-800 mb-2">Select Schedule Date</h2>
            <div class="flex items-center space-x-2">
              <div class="flex-1">
                <label for="schedule-date" class="block text-xs font-medium text-gray-700 mb-1">
                  Schedule Date
                </label>
                <input
                  id="schedule-date"
                  :value="scheduleDate"
                  @change="onPickDate"
                  type="date"
                  class="w-full px-2 py-1.5 text-sm border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
              <div class="flex flex-col space-y-1.5">
                <button 
                  @click="goToToday" 
                  class="px-2.5 py-1.5 bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 transition-colors text-xs"
                >
                  Today
                </button>
                <button 
                  @click="goToYesterday" 
                  class="px-2.5 py-1.5 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors text-xs"
                >
                  Yesterday
                </button>
                <button 
                  @click="goToTomorrow" 
                  class="px-2.5 py-1.5 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors text-xs"
                >
                  Tomorrow
                </button>
              </div>
            </div>
            <div class="mt-2 p-2 bg-blue-50 rounded-lg">
              <p class="text-xs text-blue-800">
                <strong class="mr-1">Selected:</strong>
                <ClientOnly>
                  {{ formatDate(scheduleDate) }}
                  <span v-if="isWeekend" class="ml-1.5 text-orange-600 font-medium">(Weekend)</span>
                  <span v-if="isFuture" class="ml-1.5 text-green-600 font-medium">(Future)</span>
                  <span v-if="isPast" class="ml-1.5 text-gray-600 font-medium">(Past)</span>
                </ClientOnly>
              </p>
            </div>
          </div>
        </div>

        <!-- Job Function Hours Breakdown / Dashboards (Right Side).
             min-w-0 keeps this card inside the page, level with the schedule below:
             a long day scrolls inside the card instead of pushing the page wider. -->
        <div class="flex-1 min-w-0">
          <div class="card mb-0 h-full">
            <div class="flex items-center mb-2 p-2">
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="pill in dashboardPills"
                  :key="pill.key"
                  @click="activeDashboard = pill.key"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === pill.key ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  {{ pill.label }}
                </button>
              </div>
            </div>
            <!-- Job Function Hours Breakdown -->
            <div v-if="activeDashboard === 'jobFunctions'" class="grid grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8 gap-1.5 p-2">
              <div v-for="jobFunction in jobFunctionHours" :key="jobFunction.name" class="text-center bg-gray-50 rounded-lg p-1.5 border border-gray-200 hover:shadow-sm transition-shadow">
                <div class="flex items-center justify-center mb-0.5">
                  <div 
                    class="w-2 h-2 rounded border border-gray-400 mr-1.5 shadow-sm" 
                    :style="{ backgroundColor: jobFunction.color }"
                  ></div>
                  <span class="text-[10px] font-semibold text-gray-800">{{ jobFunction.name }}</span>
                </div>
                <div class="text-[9px] text-gray-600 mb-0.5">Scheduled Hours</div>
                <div class="text-sm font-bold text-gray-900 bg-white rounded py-0.5 px-1.5 shadow-sm mb-0.5">
                  {{ jobFunction.hours }}
                </div>
                <div class="text-[9px] text-gray-600 mb-0.5">Target Hours</div>
                <div class="text-xs font-semibold text-blue-600 bg-blue-50 rounded py-0.5 px-1.5">
                  {{ getTargetHours(jobFunction.id) }}
                </div>
              </div>
            </div>
            <!-- Job Function Dashboards (Meter, Locus, Pick, X4, EM9, Speedcell, Helpdesk) -->
            <div v-else class="overflow-x-auto">
              <div class="min-w-max">
                <!-- Header Row -->
                <div class="flex border-b border-gray-200 mb-0.5 bg-gradient-to-b from-gray-50 to-white sticky top-0 z-20 shadow-sm">
                  <div class="w-28 px-1.5 py-1 text-[9px] font-semibold text-gray-700 bg-white border-r border-gray-200 sticky left-0 z-30">
                    {{ activeDashboard === 'meter' ? 'Meter' : activeDashboard }}
                  </div>
                  <div 
                    v-for="timeSlot in meterTimeSlots" 
                    :key="timeSlot.time" 
                    class="px-1 py-1 text-center text-[9px] font-semibold border-r border-gray-200 box-border" 
                    :class="{ 
                      'bg-blue-50 text-blue-700': isHourlyMarker(timeSlot.time),
                      'bg-transparent text-gray-500': !isHourlyMarker(timeSlot.time)
                    }" 
                    :style="{ width: '24px', flexShrink: 0, flexGrow: 0 }"
                  >
                    {{ formatTimeForMeterDashboard(timeSlot.time) }}
                  </div>
                </div>

                <!-- Dashboard Rows -->
                <div class="min-w-max">
                  <!-- Meter Dashboard -->
                  <template v-if="activeDashboard === 'meter'">
                    <div
                      v-for="meterNumber in ACTIVE_METER_NUMBERS"
                      :key="meterNumber"
                      class="flex border-b border-gray-100 hover:bg-gray-50/50 transition-colors"
                    >
                      <!-- Meter Label -->
                      <div class="w-28 px-1.5 py-1 text-[9px] font-medium text-gray-700 bg-white border-r border-gray-200 sticky left-0 z-10 flex items-center">
                        <span class="text-gray-600">M</span>
                        <span class="ml-0.5 font-semibold text-gray-800">{{ meterNumber }}</span>
                      </div>

                      <!-- Time Slots for this Meter -->
                      <div
                        v-for="timeSlot in meterTimeSlots"
                        :key="`meter-${meterNumber}-${timeSlot.time}`"
                        class="px-0 py-0.5 text-center border-r border-gray-100 relative box-border"
                        :class="{ 
                          'bg-blue-50/30': isHourlyMarker(timeSlot.time),
                          'bg-transparent': !isHourlyMarker(timeSlot.time)
                        }"
                        :style="{ width: '24px', flexShrink: 0, flexGrow: 0 }"
                      >
                        <div
                          class="w-full h-4 flex items-center justify-center rounded transition-all"
                          :class="getMeterSlotClasses(meterNumber, timeSlot.time)"
                          :style="getMeterSlotStyle(meterNumber, timeSlot.time)"
                        >
                          <span 
                            v-if="isMeterBooked(meterNumber, timeSlot.time)" 
                            class="w-1.5 h-1.5 rounded-full bg-white shadow-sm"
                          ></span>
                          <span 
                            v-else 
                            class="w-1 h-1 rounded-full bg-gray-200"
                          ></span>
                        </div>
                      </div>
                    </div>
                  </template>

                  <!-- Other Job Function Dashboards (Locus, Pick, X4, EM9, Speedcell, Helpdesk) -->
                  <template v-else>
                    <div
                      v-for="employee in getEmployeesForJobFunction(activeDashboard)"
                      :key="employee.id"
                      class="flex border-b border-gray-100 hover:bg-gray-50/50 transition-colors"
                    >
                      <!-- Employee Label -->
                      <div class="w-28 px-1.5 py-1 text-[9px] font-medium text-gray-700 bg-white border-r border-gray-200 sticky left-0 z-10 flex items-center">
                        <span class="text-gray-600 truncate">{{ employee.last_name }}, {{ employee.first_name }}</span>
                      </div>

                      <!-- Time Slots for this Employee -->
                      <div
                        v-for="timeSlot in meterTimeSlots"
                        :key="`${employee.id}-${timeSlot.time}`"
                        class="px-0 py-0.5 text-center border-r border-gray-100 relative box-border"
                        :class="{ 
                          'bg-blue-50/30': isHourlyMarker(timeSlot.time),
                          'bg-transparent': !isHourlyMarker(timeSlot.time)
                        }"
                        :style="{ width: '24px', flexShrink: 0, flexGrow: 0 }"
                      >
                        <div
                          class="w-full h-4 flex items-center justify-center rounded transition-all"
                          :class="[
                            isEmployeeOnBreak(employee.id, timeSlot.time) ? 'bg-gray-300' : getJobFunctionSlotClasses(employee.id, timeSlot.time, activeDashboard)
                          ]"
                          :style="isEmployeeOnBreak(employee.id, timeSlot.time) ? {} : getJobFunctionSlotStyle(employee.id, timeSlot.time, activeDashboard)"
                          :title="isEmployeeOnBreak(employee.id, timeSlot.time) ? 'Break / Lunch' : ''"
                        >
                          <span
                            v-if="isEmployeeOnBreak(employee.id, timeSlot.time)"
                            class="w-2 h-0.5 rounded-sm bg-gray-600"
                          ></span>
                          <span
                            v-else-if="isEmployeeAssignedToJobFunction(employee.id, timeSlot.time, activeDashboard)"
                            class="w-1.5 h-1.5 rounded-full bg-white shadow-sm"
                          ></span>
                          <span
                            v-else
                            class="w-1 h-1 rounded-full bg-gray-200"
                          ></span>
                        </div>
                      </div>
                    </div>
                  </template>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Save Progress Indicator -->
      <div v-if="isSaving" class="card mb-6 bg-blue-50 border-blue-200">
        <div class="flex items-center space-x-4">
          <svg class="animate-spin h-6 w-6 text-blue-600" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <div class="flex-1">
            <h3 class="text-lg font-semibold text-blue-800">Saving Schedule...</h3>
            <p class="text-sm text-blue-700">{{ saveProgress }}</p>
            <p class="text-xs text-blue-600 mt-1">
              💡 You can navigate away from this page - the save will continue in the background
            </p>
          </div>
        </div>
      </div>


      <!-- Shift-Based Schedule Layout -->
      <div v-if="loading" class="card text-center py-8">
        <p class="text-gray-600">Loading schedule data...</p>
      </div>
      
      <div v-else-if="error" class="card text-center py-8">
        <p class="text-red-600">Error loading schedule: {{ error }}</p>
      </div>
      
      <div v-else-if="!employees.length" class="card text-center py-8">
        <p class="text-gray-600">No employees found. Please add employees first.</p>
      </div>
      
      <!-- Full-width schedule container with horizontal scroll -->
      <div v-else class="w-full overflow-x-auto">
        <div>
          <ShiftGroupedSchedule
            :employees="employees"
            :schedule-assignments="scheduleAssignments"
            :job-functions="jobFunctions"
            :shifts="scheduleData"
            :schedule-assignments-data="scheduleAssignmentsData"
            :training-by-employee="trainingByEmployee"
            :pto-by-employee-id="ptoByEmployeeId"
            :shift-swaps-by-employee-id="swapByEmployeeId"
            :preferred-assignments-map="preferredBadgeMap"
            @add-assignment="handleAddAssignment"
            @addPTO="openPTOModal"
            @addShiftSwap="openShiftSwapModal"
            @addCallIn="openCallInModal"
            @clearEmployee="handleClearEmployee"
          />
        </div>
      </div>

      <!-- PTO Modal -->
      <div v-if="showPTOModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 max-h-[90vh] overflow-y-auto">
          <h3 class="text-xl font-bold mb-4">Add Absence</h3>
          <div class="space-y-3">
            <div v-if="resolvedPtoRecord" class="p-3 bg-blue-50 border border-blue-200 rounded-md text-sm text-blue-800">
              Absence already exists for this employee on {{ formatDate(scheduleDate) }}.
              Update the details below or use Cancel PTO if they are working.
            </div>
            <div v-if="ptoModalCallIn" class="p-3 bg-orange-50 border border-orange-200 rounded-md text-sm text-orange-800">
              Also marked as called in that day. The call-in stays as it is — use CI on their row
              to change or remove it.
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Date</label>
              <input v-model="ptoForm.pto_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-md" />
            </div>
            <div class="flex items-center gap-2">
              <input id="full_day" v-model="ptoForm.full_day" type="checkbox" class="h-4 w-4 text-blue-600 border-gray-300 rounded" />
              <label for="full_day" class="text-sm text-gray-700">Full day</label>
            </div>
            <div class="grid grid-cols-2 gap-3" v-if="!ptoForm.full_day">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Start</label>
                <input v-model="ptoForm.start_time" type="time" class="w-full px-3 py-2 border border-gray-300 rounded-md" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">End</label>
                <input v-model="ptoForm.end_time" type="time" class="w-full px-3 py-2 border border-gray-300 rounded-md" />
              </div>
            </div>
            <div class="flex flex-wrap items-center justify-end gap-2 pt-2">
              <button
                v-if="resolvedPtoRecord"
                type="button"
                @click="deleteCurrentPTO"
                class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 mr-auto"
              >
                Cancel PTO
              </button>
              <button type="button" @click="closePTOModal" class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
                Close
              </button>
              <button type="button" @click="savePTO" class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                Save PTO
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Call-In Modal -->
      <div v-if="showCallInModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 max-h-[90vh] overflow-y-auto">
          <h3 class="text-xl font-bold mb-4">Mark as Call-In</h3>
          <div class="space-y-3">
            <div v-if="resolvedCallInRecord" class="p-3 bg-orange-50 border border-orange-200 rounded-md text-sm text-orange-800">
              This employee is already marked as called in on {{ formatDate(scheduleDate) }}.
              Update the note below or use Remove Call-In to clear.
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Date</label>
              <input v-model="callInForm.pto_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-md" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Notes (optional)</label>
              <input v-model="callInForm.notes" type="text" placeholder="e.g. sick, family emergency" class="w-full px-3 py-2 border border-gray-300 rounded-md" />
            </div>
            <div class="flex flex-wrap items-center justify-end gap-2 pt-2">
              <button
                v-if="resolvedCallInRecord"
                type="button"
                @click="deleteCurrentCallIn"
                class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 mr-auto"
              >
                Remove Call-In
              </button>
              <button type="button" @click="closeCallInModal" class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
                Close
              </button>
              <button type="button" @click="saveCallIn" class="px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700">
                Save Call-In
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Notification Modal — above the other popups (z-60), so an error raised
           while one is open (e.g. a failed shift swap) isn't hidden behind it. -->
      <div v-if="showNotificationModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[60]">
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-xl font-bold text-gray-800">{{ notificationType === 'success' ? '✅ Success' : '❌ Error' }}</h3>
            <button @click="closeNotificationModal" class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div :class="notificationType === 'success' ? 'bg-green-50 border border-green-200 rounded-lg p-4 mb-4' : 'bg-red-50 border border-red-200 rounded-lg p-4 mb-4'">
            <p :class="notificationType === 'success' ? 'text-green-800' : 'text-red-800'" class="text-sm">{{ notificationMessage }}</p>
          </div>
          <div class="flex justify-end">
            <button
              @click="closeNotificationModal"
              :class="notificationType === 'success' ? 'px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium' : 'px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium'"
            >
              OK
            </button>
          </div>
        </div>
      </div>

      <!-- Shift Swap Modal -->
      <div v-if="showShiftSwapModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 max-h-[90vh] overflow-y-auto">
          <h3 class="text-xl font-bold mb-4">Shift Swap</h3>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Employee</label>
              <input 
                :value="selectedSwapEmployee ? `${selectedSwapEmployee.first_name} ${selectedSwapEmployee.last_name}` : ''" 
                type="text" 
                disabled
                class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100" 
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Date</label>
              <input v-model="shiftSwapForm.swap_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-md" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Original Shift</label>
              <input 
                :value="getShiftName(shiftSwapForm.original_shift_id)" 
                type="text" 
                disabled
                class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100" 
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Swap To Shift</label>
              <select v-model="shiftSwapForm.swapped_shift_id" class="w-full px-3 py-2 border border-gray-300 rounded-md">
                <option value="">Select a shift...</option>
                <option 
                  v-for="shift in scheduleData" 
                  :key="shift.id" 
                  :value="shift.id"
                  :disabled="shift.id === shiftSwapForm.original_shift_id"
                >
                  {{ shift.name }}
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Notes (optional)</label>
              <textarea v-model="shiftSwapForm.notes" rows="2" class="w-full px-3 py-2 border border-gray-300 rounded-md"></textarea>
            </div>
            <div v-if="swapEmployeeHasAssignments" class="p-3 bg-amber-50 border border-amber-200 rounded-md text-sm text-amber-800">
              They already have assignments today. Changing or removing their swap clears those,
              so you can assign them on the right shift afterwards.
            </div>
            <div class="flex justify-end gap-2 pt-2">
              <button @click="closeShiftSwapModal" class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">Cancel</button>
              <button 
                v-if="existingShiftSwap"
                @click="deleteShiftSwap" 
                class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
              >
                Remove Swap
              </button>
              <button 
                @click="saveShiftSwap" 
                :disabled="!shiftSwapForm.swapped_shift_id"
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {{ existingShiftSwap ? 'Update Swap' : 'Save Swap' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Export historical schedule -->
    <div
      v-if="showExportModal"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
      @click.self="showExportModal = false"
    >
      <div class="bg-white rounded-xl shadow-2xl max-w-md w-full">
        <div class="p-6">
          <div class="flex justify-between items-center mb-1">
            <h2 class="text-xl font-bold text-gray-900">Export Schedule</h2>
            <button @click="showExportModal = false" class="text-gray-400 hover:text-gray-600 text-2xl leading-none">&times;</button>
          </div>
          <p class="text-sm text-gray-500 mb-4">
            Download any past or upcoming schedule as a CSV, one row per assignment.
          </p>

          <div class="grid grid-cols-2 gap-3 mb-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">From</label>
              <input
                v-model="exportFrom"
                type="date"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">To</label>
              <input
                v-model="exportTo"
                type="date"
                :min="exportFrom"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
              />
            </div>
          </div>

          <div class="flex flex-wrap gap-2 mb-4">
            <button type="button" @click="setExportRange('day')" class="px-2.5 py-1 text-xs rounded border border-gray-300 text-gray-600 hover:bg-gray-50">This day</button>
            <button type="button" @click="setExportRange('week')" class="px-2.5 py-1 text-xs rounded border border-gray-300 text-gray-600 hover:bg-gray-50">Last 7 days</button>
            <button type="button" @click="setExportRange('month')" class="px-2.5 py-1 text-xs rounded border border-gray-300 text-gray-600 hover:bg-gray-50">Last 30 days</button>
            <button type="button" @click="setExportRange('year')" class="px-2.5 py-1 text-xs rounded border border-gray-300 text-gray-600 hover:bg-gray-50">Last 12 months</button>
          </div>

          <div v-if="exportError" class="bg-red-50 border border-red-200 rounded-md p-3 mb-3">
            <p class="text-sm text-red-600">{{ exportError }}</p>
          </div>

          <button
            @click="downloadScheduleCsv"
            :disabled="exporting || !exportFrom || !exportTo"
            class="w-full px-4 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 font-medium"
          >
            {{ exporting ? 'Preparing...' : 'Download CSV' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Import the component explicitly
import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router'
import ShiftGroupedSchedule from '~/components/schedule/ShiftGroupedSchedule.vue'
import { toLocalISO, addDays } from '~/utils/localDate'
import { describePto, formatTimeOfDay, MINUTES_IN_DAY } from '~/utils/ptoDisplay'
import { workableSlots, type WorkableSlots } from '~/utils/workableSlots'

// Use real composables instead of mock data
const { 
  employees, 
  loading: employeesLoading, 
  error: employeesError, 
  fetchEmployees,
  getAllEmployeeTraining
} = useEmployees()

const { 
  jobFunctions, 
  loading: functionsLoading, 
  error: functionsError, 
  fetchJobFunctions 
} = useJobFunctions()

const { 
  shifts, 
  loading: shiftsLoading, 
  error: shiftsError, 
  fetchShifts 
} = useSchedule()

const {
  scheduleAssignments: scheduleAssignmentsRef,
  loading: assignmentsLoading,
  error: assignmentsError,
  fetchScheduleForDate,
  fetchTargetHours,
  replaceScheduleForDate,
  createAssignment,
  deleteAssignment,
  fetchScheduleExport
} = useSchedule()

// --- Historical schedule CSV export -------------------------------------------
const showExportModal = ref(false)
const exporting = ref(false)
const exportError = ref('')
const exportFrom = ref('')
const exportTo = ref('')

const toDateStr = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

const setExportRange = (preset: 'day' | 'week' | 'month' | 'year') => {
  const end = scheduleDate.value || toDateStr(new Date())
  if (preset === 'day') {
    exportFrom.value = end
    exportTo.value = end
    return
  }
  const [y, m, d] = end.split('-').map(Number)
  const start = new Date(y, m - 1, d)
  if (preset === 'week') start.setDate(start.getDate() - 6)
  else if (preset === 'month') start.setDate(start.getDate() - 29)
  else start.setFullYear(start.getFullYear() - 1)
  exportFrom.value = toDateStr(start)
  exportTo.value = end
}

const csvEscape = (v: any) => {
  const s = String(v ?? '')
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}

const downloadScheduleCsv = async () => {
  exporting.value = true
  exportError.value = ''
  try {
    const rows = await fetchScheduleExport(exportFrom.value, exportTo.value)
    if (!rows.length) {
      exportError.value = 'No assignments found in that date range.'
      return
    }

    const header = ['Date', 'Last Name', 'First Name', 'Job Function', 'Shift', 'Start', 'End', 'Hours']
    const lines = [header.join(',')]
    for (const r of rows) {
      lines.push([
        r.schedule_date, r.last_name, r.first_name, r.job_function_name,
        r.shift_name, r.start_time, r.end_time, r.hours,
      ].map(csvEscape).join(','))
    }

    // UTF-8 BOM so Excel decodes accented names correctly rather than as Windows-1252.
    const blob = new Blob([String.fromCharCode(0xFEFF) + lines.join('\r\n')], {
      type: 'text/csv;charset=utf-8;',
    })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = exportFrom.value === exportTo.value
      ? `schedule-${exportFrom.value}.csv`
      : `schedule-${exportFrom.value}_to_${exportTo.value}.csv`
    a.click()
    URL.revokeObjectURL(url)
    showExportModal.value = false
  } catch (e: any) {
    exportError.value = e.data?.message || e.message || 'Export failed'
  } finally {
    exporting.value = false
  }
}

// Default the range to the schedule currently being viewed.
watch(showExportModal, (open) => {
  if (open && !exportFrom.value) setExportRange('day')
})

// PTO composable
const {
  ptoRecords,
  ptoByEmployeeId,
  fetchPTOForDate,
  createPTO,
  deletePTO
} = usePTO()

const {
  shiftSwaps,
  swapByEmployeeId,
  fetchShiftSwapsForDate,
  createShiftSwap,
  deleteShiftSwap: deleteShiftSwapAction,
  getSwapForEmployee
} = useShiftSwaps()

// Preferred Assignments composable
const {
  preferredAssignments,
  fetchPreferredAssignments
} = usePreferredAssignments()

/**
 * Required / Preferred badges in the assign popup: employee → job function → pin.
 *
 * A pin made of time blocks (X4 in the morning, EM9 after lunch) badges EVERY
 * block's function. getPreferredAssignmentsMap() keys only on the pin's base
 * function — the first block's — so the afternoon function showed no badge. That
 * map feeds the builder and is left alone; this one is for display only.
 */
const preferredBadgeMap = computed(() => {
  const map: Record<string, Record<string, any>> = {}
  for (const pa of preferredAssignments.value || []) {
    const fnIds = [pa.job_function_id, ...(pa.blocks || []).map((b: any) => b.job_function_id)]
    for (const id of fnIds) {
      if (!id) continue
      // Rows arrive highest priority first; keep that pin when two share a function.
      ;(map[pa.employee_id] ||= {})[id] ??= pa
    }
  }
  return map
})

// Ensure scheduleAssignments is always an array
const scheduleAssignments = computed(() => (scheduleAssignmentsRef.value || []) as any[])

// Create schedule data from shifts
const scheduleData = computed(() => {
  if (!shifts.value || shifts.value.length === 0) return []
  return shifts.value.map((shift: any) => ({
    id: shift.id,
    name: shift.name,
    start_time: shift.start_time,
    end_time: shift.end_time,
    break_1_start: shift.break_1_start,
    break_1_end: shift.break_1_end,
    break_2_start: shift.break_2_start,
    break_2_end: shift.break_2_end,
    lunch_start: shift.lunch_start,
    lunch_end: shift.lunch_end,
    employee_count: 0 // Will be calculated
  }))
})

/** The shift someone actually works on this date — their swap's shift, if they have one. */
const shiftForEmployee = (employeeId: string): any | null => {
  const emp = employees.value?.find((e: any) => e.id === employeeId)
  const shiftId = swapByEmployeeId.value?.[employeeId]?.swapped_shift_id ?? emp?.shift_id
  return shiftId ? shifts.value?.find((s: any) => s.id === shiftId) ?? null : null
}

// Data loading. The full-page "Loading…" and "Error loading…" states are for the
// FIRST load only. Later fetches — after a save, a call-in, a swap — refresh the
// grid in place. They used to swap it for the loading message, which unmounted it
// and threw the page back to the top, and a failed save's error replaced the grid.
const firstLoadDone = ref(false)
const loadError = computed(() =>
  employeesError.value || functionsError.value || shiftsError.value || assignmentsError.value
)
const error = computed(() => (firstLoadDone.value ? null : loadError.value))
const loading = computed(() => !firstLoadDone.value && !error.value)

// Training data: employee_id -> job_function_id[]
const trainingByEmployee = ref<Record<string, string[]>>({})

const scheduleAssignmentsData = ref<Record<string, any>>({})

// --- Unsaved-change tracking --------------------------------------------------
// Edits live only in scheduleAssignmentsData until "Save Schedule" is pressed.
// Anything that rebuilds the grid from the server therefore destroys them, which
// is exactly how a call-in used to wipe out unsaved work. We snapshot the grid
// whenever it matches the server, and compare against that snapshot to know
// whether there is anything at risk.
const savedSnapshot = ref('')

/** Order-independent serialisation, so key ordering can't fake a change. */
const gridFingerprint = (grid: Record<string, any>): string => {
  const empIds = Object.keys(grid || {}).sort()
  return JSON.stringify(
    empIds.map((id) => {
      const slots = grid[id] || {}
      return [id, Object.keys(slots).sort().map((k) => [k, slots[k]])]
    })
  )
}

const markGridSaved = () => { savedSnapshot.value = gridFingerprint(scheduleAssignmentsData.value) }

const hasUnsavedChanges = computed(
  () => savedSnapshot.value !== '' && gridFingerprint(scheduleAssignmentsData.value) !== savedSnapshot.value
)

// Save state
const isSaving = ref(false)
const saveProgress = ref('')

// Target hours state
const targetHours = ref({})

// Dashboard state - tracks which dashboard view is active
// 'jobFunctions' = summary cards, 'meter' = grouped Meter grid (only when Meter exists),
// otherwise the key is the actual job function name (the detail grid matches by name).
const activeDashboard = ref<string>('jobFunctions')

// Dynamic dashboard selector pills, built from the real active job functions so new/renamed
// functions appear automatically and stale ones don't. Individual "Meter N" children are
// folded into a single "Meter" pill; the "Meter" parent isn't shown as its own pill.
const dashboardPills = computed<{ key: string; label: string }[]>(() => {
  const pills: { key: string; label: string }[] = [{ key: 'jobFunctions', label: 'Job Functions' }]
  const jfs = (jobFunctions.value || []).filter((jf: any) => jf?.is_active !== false && jf?.name)
  const isMeterChild = (n: string) => /^Meter \d+$/.test(n)
  if (jfs.some((jf: any) => jf.name === 'Meter' || isMeterChild(jf.name))) {
    pills.push({ key: 'meter', label: 'Meter' })
  }
  jfs
    .filter((jf: any) => jf.name !== 'Meter' && !isMeterChild(jf.name))
    .sort((a: any, b: any) => (a.sort_order ?? 0) - (b.sort_order ?? 0) || a.name.localeCompare(b.name))
    .forEach((jf: any) => pills.push({ key: jf.name, label: jf.name }))
  return pills
})
const meterBookings = ref<Record<string, number>>({}) // Changed to number to track count of bookings

// The date comes from the URL and is fixed for the life of the page: every date
// change is a navigation, and Nuxt builds a fresh page for each /schedule/<date>.
const route = useRoute()
const scheduleDate = ref('')

/**
 * Go to another date. Always through the router, so the URL, the browser's Back
 * button and the unsaved-changes prompt (onBeforeRouteUpdate, below) all follow.
 * The picker used to change the date in place — no prompt, URL left behind — and
 * the buttons set it before navigating, so either way unsaved edits vanished.
 */
const goToDate = async (date: string) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || date === scheduleDate.value) return
  await navigateTo(`/schedule/${date}`)
}

// "Today" is the browser's own calendar day — the same one the home page links to.
// It used to be pinned to America/Chicago, wrong for a site in any other timezone.
const goToToday = () => goToDate(toLocalISO(new Date()))
const goToYesterday = () => goToDate(toLocalISO(addDays(new Date(), -1)))
const goToTomorrow = () => goToDate(toLocalISO(addDays(new Date(), 1)))

const onPickDate = async (e: Event) => {
  const input = e.target as HTMLInputElement
  const date = input.value
  // Typing a year digit by digit passes through dates like 0002-09-24 — ignore those.
  if (!/^(19|20)\d{2}-\d{2}-\d{2}$/.test(date)) return
  await goToDate(date)
  // Still on this page (they chose to keep their edits): put the picker back.
  if (route.params.date !== date) input.value = scheduleDate.value
}

// YYYY-MM-DD strings compare correctly as text. These used `new Date('YYYY-MM-DD')`,
// which is midnight UTC — the previous evening in the US — so today read "(Past)"
// and "(Weekend)" landed on Sunday and Monday.
const todayISO = toLocalISO(new Date())
const isFuture = computed(() => !!scheduleDate.value && scheduleDate.value > todayISO)
const isPast = computed(() => !!scheduleDate.value && scheduleDate.value < todayISO)
const isWeekend = computed(() => {
  if (!scheduleDate.value) return false
  const [y, m, d] = scheduleDate.value.split('-').map(Number)
  const day = new Date(y!, m! - 1, d!).getDay()
  return day === 0 || day === 6 // Sunday or Saturday
})

// Reload target hours when page becomes active (for SPA navigation)
onActivated(() => {
  loadTargetHours()
})

// Listen for localStorage changes (when target hours are updated in another tab/page)
onMounted(() => {
  // Also listen for focus events to refresh when returning to the page
  const handleFocus = () => {
    loadTargetHours()
  }
  
  window.addEventListener('focus', handleFocus)
  
  // Cleanup on unmount
  onUnmounted(() => {
    window.removeEventListener('focus', handleFocus)
  })
})

// Target hours — the default per-function hours saved in Team Setup → Target
// Hours tab (the `target_hours` table). NOTE: this is intentionally NOT `daily_targets`
// (that table stores per-date target *units*, a different concept); reading daily_targets
// here was the bug that always showed 0.
const loadTargetHours = async () => {
  try {
    targetHours.value = (await fetchTargetHours()) || {}
  } catch {
    targetHours.value = {}
  }
}

const getTargetHours = (jobFunctionId: string) => {
  if (!targetHours.value || Object.keys(targetHours.value).length === 0) return 0
  if (jobFunctionId === 'meter-group') {
    let total = 0
    jobFunctions.value.forEach((job: any) => {
      if (job.name.startsWith('Meter ')) {
        const h = targetHours.value[job.id]
        if (h !== undefined && h !== null) total += h
      }
    })
    return total
  }
  const hours = targetHours.value[jobFunctionId]
  return hours !== undefined && hours !== null ? hours : 0
}

// Helper function to generate all 15-minute time slots between start and end
const generateTimeSlots = (startTime: string, endTime: string): string[] => {
  const slots: string[] = []
  const startMinutes = timeToMinutes(startTime.substring(0, 5)) // "07:00:00" -> "07:00" -> minutes
  const endMinutes = timeToMinutes(endTime.substring(0, 5))
  
  let currentMinutes = startMinutes
  while (currentMinutes < endMinutes) {
    slots.push(minutesToTime(currentMinutes)) // Convert back to "HH:MM" format
    currentMinutes += 15 // Add 15 minutes for each slot
  }
  
  return slots
}

// Initialize schedule data from existing assignments
const initializeScheduleData = () => {
  const initialData: Record<string, any> = {}
  
  // Initialize data for each employee
  employees.value.forEach((employee: any) => {
    initialData[employee.id] = {}
  })
  
  // Add existing assignments - fill in ALL 15-minute slots between start and end
  scheduleAssignments.value.forEach((assignment: any) => {
    if (!initialData[assignment.employee_id]) {
      initialData[assignment.employee_id] = {}
    }
    
    const jobFunction = jobFunctions.value.find((jf: any) => jf.id === assignment.job_function_id)
    if (jobFunction && assignment.start_time && assignment.end_time) {
      // Generate all 15-minute slots between start_time and end_time
      const startTime = assignment.start_time.substring(0, 5) // "07:00:00" -> "07:00"
      const endTime = assignment.end_time.substring(0, 5)
      const timeSlots = generateTimeSlots(startTime, endTime)
      
      // Normalize job function name for consistent merging (especially Lunch/Break)
      const normalizedName = jobFunction.name === 'Lunch' ? 'LUNCH' : 
                             jobFunction.name === 'Break' ? 'BREAK' :
                             jobFunction.name === 'Break 1' ? 'BREAK 1' :
                             jobFunction.name === 'Break 2' ? 'BREAK 2' :
                             jobFunction.name
      
      // Fill in each 15-minute slot with the assignment
      timeSlots.forEach((timeSlot: string) => {
        if (!initialData[assignment.employee_id][timeSlot]) {
          initialData[assignment.employee_id][timeSlot] = {}
        }
        // Set assignment and until time for this slot (use normalized name)
        initialData[assignment.employee_id][timeSlot].assignment = normalizedName
        initialData[assignment.employee_id][timeSlot].until = endTime
      })
    }
  })
  
  scheduleAssignmentsData.value = initialData
  // The grid now mirrors the server, so this is the baseline for "unsaved".
  markGridSaved()
}

// Load everything once, in parallel. Two onMounted hooks and a date watcher used
// to overlap here, so the day's assignments, PTO, swaps, pins and target hours
// were each fetched twice on every visit.
onMounted(async () => {
  scheduleDate.value = (route.params.date as string) || toLocalISO(new Date())
  try {
    await Promise.all([
      fetchEmployees(),
      fetchJobFunctions(),
      fetchShifts(),
      fetchScheduleForDate(scheduleDate.value),
      fetchPTOForDate(scheduleDate.value),
      fetchShiftSwapsForDate(scheduleDate.value),
      fetchPreferredAssignments(),
      loadTargetHours(),
      loadPtoUsed(),
      getAllEmployeeTraining().then((training) => { trainingByEmployee.value = training || {} }),
    ])
    await nextTick()
    initializeScheduleData()
    syncMeterBookings()
  } catch (error) {
    console.error('Error loading schedule data:', error)
  }
  firstLoadDone.value = !loadError.value
})

// --- KPI strip -----------------------------------------------------------------
// Everyone counts as one person, and the figures follow the grid as you edit. The
// old tiles counted a hardcoded 4:00–8:30 PM shift as half a person (and halved its
// HOURS too), took Labor Hours from shift lengths rather than the schedule, and
// priced PTO themselves.

/** Each person with a shift today: their working slots, and what's left after time off. */
const dayShapes = computed(() => {
  const out: Record<string, WorkableSlots> = {}
  for (const e of employees.value || []) {
    const shift = shiftForEmployee(e.id)
    const w = shift ? workableSlots(shift, ptoByEmployeeId.value?.[e.id] || []) : null
    if (w) out[e.id] = w
  }
  return out
})

/** On a shift today and not off for all of it. */
const workingToday = computed(() =>
  Object.keys(dayShapes.value).filter((id) => dayShapes.value[id]!.free.includes(1))
)

/** Slot numbers (minute / 15) with something assigned on the grid. */
const assignedSlots = (employeeId: string): number[] =>
  Object.entries(scheduleAssignmentsData.value?.[employeeId] || {})
    .filter(([, slot]: [string, any]) => slot?.assignment)
    .map(([time]) => Math.floor(timeToMinutes(time) / 15))

const totalEmployees = computed(() => workingToday.value.length)

/**
 * Labor Hours Available: the hours people are on the floor today — each person's
 * shift minus lunch, breaks and time off (utils/workableSlots.ts, the same rule the
 * builder schedules into).
 */
const laborHoursAvailable = computed(() => {
  let slots = 0
  for (const w of Object.values(dayShapes.value)) for (const v of w.free) slots += v
  return slots / 4
})

const totalShifts = computed(() => shifts.value.length)

/** Working today with nothing on the grid yet. Someone off all day isn't "unassigned". */
const unassignedEmployees = computed(() =>
  workingToday.value.filter((id) => assignedSlots(id).length === 0).length
)

/**
 * Today's time off in paid hours, from the server: the figure the daily PTO cap
 * measures (server/utils/ptoHours.ts). Never priced here — this tile used to do its
 * own sums and read an arrive-late as starting at midnight (34h for a real 18h).
 */
const ptoUsed = ref<{ used: number; cap: number } | null>(null)
const loadPtoUsed = async () => {
  try {
    const res = await $fetch<any>('/api/pto/availability', {
      params: { date_from: scheduleDate.value, date_to: scheduleDate.value },
    })
    const day = res?.days?.[0]
    ptoUsed.value = day ? { used: Number(day.used) || 0, cap: Number(day.cap) || 0 } : null
  } catch {
    ptoUsed.value = null
  }
}

/** Re-read the day's absences after one changes — the rows and the paid hours. */
const refreshAbsences = () => Promise.all([fetchPTOForDate(scheduleDate.value), loadPtoUsed()])

const fmtHours = (h: number) => String(Math.round(h * 10) / 10)

const jobFunctionHours = computed(() => {
  if (!jobFunctions.value || !scheduleAssignmentsData.value) return []
  
  // Calculate hours based on actual schedule data from the component
  const jobFunctionTotals: Record<string, number> = {}
  
  // Initialize all job functions with 0 hours
  jobFunctions.value.forEach((job: any) => {
    jobFunctionTotals[job.name] = 0
  })
  
  // Always initialize Meter entry for grouping
  jobFunctionTotals['Meter'] = 0
  
  // Helper function to check if a time slot is lunch time (unpaid)
  const isLunchTime = (timeSlot: string, employeeId: string): boolean => {
    const employee = employees.value.find((e: any) => e.id === employeeId)
    if (!employee || !employee.shift_id) return false
    
    // Account for shift swaps
    const swap = swapByEmployeeId.value?.[employeeId]
    const actualShiftId = swap ? swap.swapped_shift_id : employee.shift_id
    
    const shift = scheduleData.value.find((s: any) => s.id === actualShiftId)
    if (!shift || !shift.lunch_start || !shift.lunch_end) return false
    
    // Convert time slot to minutes (format: "HH:MM")
    const timeMinutes = timeToMinutes(timeSlot)
    const lunchStartMinutes = timeToMinutes(shift.lunch_start.substring(0, 5))
    const lunchEndMinutes = timeToMinutes(shift.lunch_end.substring(0, 5))
    
    // Check if time slot falls within lunch period
    return timeMinutes >= lunchStartMinutes && timeMinutes < lunchEndMinutes
  }
  
  // Calculate hours for each employee's schedule
  Object.entries(scheduleAssignmentsData.value).forEach(([employeeId, employeeSchedule]: [string, any]) => {
    Object.entries(employeeSchedule).forEach(([timeSlot, data]: [string, any]) => {
      if (data.assignment && data.assignment.trim() !== '') {
        // Skip lunch time (unpaid) - but keep breaks (paid)
        if (isLunchTime(timeSlot, employeeId)) {
          return // Skip this time slot
        }
        
        // Each 15-minute slot = 0.25 hours
        const jobName = data.assignment
        
        // If it's a meter assignment, count it under 'Meter'
        if (jobName.startsWith('Meter ')) {
          jobFunctionTotals['Meter'] = (jobFunctionTotals['Meter'] || 0) + 0.25
        } else if (jobFunctionTotals.hasOwnProperty(jobName)) {
          jobFunctionTotals[jobName] += 0.25
        }
      }
    })
  })
  
  // Group meter hours together
  const groupedJobFunctions: Record<string, any> = {}
  let meterColor = '#87CEEB' // Default meter color
  
  // Find the actual meter color from any existing meter job function
  const firstMeterJobFunction = jobFunctions.value.find((job: any) => job.name && job.name.startsWith('Meter '))
  if (firstMeterJobFunction) {
    meterColor = firstMeterJobFunction.color_code
  }
  
  jobFunctions.value.forEach((job: any) => {
    if (!job.name.startsWith('Meter ')) { // Exclude individual meters from direct display
      groupedJobFunctions[job.name] = {
        id: job.id,
        name: job.name,
        color: job.color_code,
        hours: Math.round((jobFunctionTotals[job.name] || 0) * 10) / 10,
        employees: 0
      }
    }
  })
  
  // Add grouped meter entry if there are any meter assignments
  if (jobFunctionTotals['Meter'] > 0) {
    groupedJobFunctions['Meter'] = {
      id: 'meter-group',
      name: 'Meter',
      color: meterColor, // This will now use the reliably found meter color
      hours: Math.round(jobFunctionTotals['Meter'] * 10) / 10,
      employees: 0
    }
  }
  
  return Object.values(groupedJobFunctions)
})

// Functions
const formatDate = (dateString: string) => {
  if (!dateString) return ''
  try {
    // Handle YYYY-MM-DD safely as a local date (avoid UTC shift)
    if (/^\d{4}-\d{2}-\d{2}$/.test(dateString)) {
      const [y, m, d] = dateString.split('-').map(Number)
      const localDate = new Date(y, (m || 1) - 1, d || 1)
      return localDate.toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      })
    }
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })
  } catch (error) {
    return dateString
  }
}

// Time utility functions
const timeToMinutes = (timeStr: string): number => {
  const [hours, minutes] = timeStr.split(':').map(Number)
  return hours * 60 + minutes
}

const minutesToTime = (minutes: number): string => {
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`
}

/**
 * Returns true when the schedule is safely persisted, false if the save failed.
 * `quiet` skips the success message — for saves folded into another action
 * (call-in, swap, Clear All), which say "Your changes were saved." in their own.
 */
const saveSchedule = async (quiet = false): Promise<boolean> => {
  const assignmentsToSave: any[] = []
  try {
    isSaving.value = true
    saveProgress.value = 'Preparing to save schedule...'

    // Convert scheduleAssignmentsData into contiguous ranges and save (atomic replace)
    saveProgress.value = 'Processing schedule data (merging ranges)...'

    // Every 15-minute slot of the day, across all active shifts
    const allSlots: string[] = daySlots.value

    Object.entries(scheduleAssignmentsData.value).forEach(([employeeId, employeeSchedule]) => {
      let currentLabel = ''
      let currentStartTime = ''
      let currentShift: any = null
      let currentJobFunctionId: string | null = null

      const flushRange = (endSlot: string) => {
        if (!currentLabel || !currentShift || !currentJobFunctionId || !currentStartTime) return
        assignmentsToSave.push({
          employee_id: employeeId,
          job_function_id: currentJobFunctionId,
          shift_id: currentShift.id,
          start_time: currentStartTime,
          end_time: endSlot,
          schedule_date: scheduleDate.value
        })
        currentLabel = ''
        currentStartTime = ''
        currentShift = null
        currentJobFunctionId = null
      }

      for (let i = 0; i < allSlots.length; i++) {
        const slot = allSlots[i]
        const data = (employeeSchedule as any)[slot]
        const label = data && data.assignment ? String(data.assignment).trim() : ''

        if (label) {
          const jobFunction = jobFunctions.value.find((jf: any) => jf.name === label)

          const slotMinutes = timeToMinutes(slot)
          const employee = (employees.value as any[] | undefined)?.find((e: any) => e.id === employeeId) as any
          const swap = (swapByEmployeeId.value as Record<string, any> | undefined)?.[employeeId]

          let targetShiftId = swap ? swap.swapped_shift_id : (employee ? employee.shift_id : null)
          let shift = targetShiftId 
            ? (shifts.value as any[] | undefined)?.find((s: any) => s.id === targetShiftId) ?? null
            : null

          if (!shift) {
            shift = (shifts.value as any[] | undefined)?.find((s: any) => {
              const start = timeToMinutes(String(s.start_time ?? '').substring(0, 5))
              const end = timeToMinutes(String(s.end_time ?? '').substring(0, 5))
              return slotMinutes >= start && slotMinutes < end
            }) || null
          }

          if (!jobFunction || !shift) {
            // Cannot place this slot — end any current range and skip
            if (currentLabel) flushRange(slot)
            continue
          }

          const normalizedLabel = label.toLowerCase()
          const normalizedCurrent = currentLabel.toLowerCase()

          const canMerge =
            normalizedLabel === normalizedCurrent ||
            (normalizedLabel.startsWith('lunch') && normalizedCurrent.startsWith('lunch')) ||
            (normalizedLabel.startsWith('break') && normalizedCurrent.startsWith('break'))

          if (canMerge && currentShift && currentShift.id === shift.id && currentJobFunctionId === jobFunction.id) {
            continue
          }

          if (currentLabel) flushRange(slot)
          currentLabel = label
          currentStartTime = slot
          currentShift = shift
          currentJobFunctionId = jobFunction.id
        } else {
          // Empty slot — close current range if any
          if (currentLabel) flushRange(slot)
        }
      }

      // Close any trailing range at the end of the day
      if (currentLabel) {
        const lastEnd = minutesToTime(timeToMinutes(allSlots[allSlots.length - 1]) + 15)
        flushRange(lastEnd)
      }
    })
    
    // Atomic replace: DELETE + INSERT in one transaction (preserves previous schedule on failure)
    saveProgress.value = `Saving ${assignmentsToSave.length} assignments...`
    const result = await replaceScheduleForDate(scheduleDate.value, assignmentsToSave)
    if (!result) throw new Error(assignmentsError.value || 'Failed to replace schedule')
    
    // Refresh the schedule data
    saveProgress.value = 'Refreshing schedule data...'
    await fetchScheduleForDate(scheduleDate.value)
    
    // Success!
    isSaving.value = false
    saveProgress.value = ''
    // What's on screen is now what's on the server.
    markGridSaved()
    if (!quiet) showNotification(`Schedule saved successfully! ${assignmentsToSave.length} assignments created.`, 'success')
    return true

  } catch (error: any) {
    console.error('Error saving schedule:', error)
    isSaving.value = false
    saveProgress.value = ''
    // The replace is one transaction, so nothing changed on the server — and the
    // edits are still on screen. Leave them there to be fixed and saved again. This
    // used to reload the day from the server, throwing every unsaved edit away.
    saveError.value = describeSaveError(error, assignmentsToSave)
    if (!quiet) {
      showNotification(
        `Your changes were not saved. ${saveError.value} Your edits are still on screen — fix that and press Save again.`,
        'error'
      )
    }
    return false
  }
}

/** Why the last save failed, in words a lead can act on. */
const saveError = ref('')

/**
 * The server names a refused row only by its position ("Assignment 12 of 175
 * failed: Employee is not trained for this job function"). Turn that into the
 * person, function and time it was.
 */
const describeSaveError = (err: any, sent: any[]): string => {
  const msg = String(err?.message || 'Unknown error').trim()
  const m = /Assignment (\d+)(?: of \d+)?(?: failed)?: ([\s\S]*)$/.exec(msg)
  const row = m ? sent[Number(m[1]) - 1] : null
  if (!m || !row) return /[.!?]$/.test(msg) ? msg : `${msg}.`
  const who = employees.value.find((e: any) => e.id === row.employee_id)
  const fn = jobFunctions.value.find((j: any) => j.id === row.job_function_id)
  const when = `${formatTimeOfDay(timeToMinutes(row.start_time))}–${formatTimeOfDay(timeToMinutes(row.end_time))}`
  const reason = m[2]!.trim().replace(/\.$/, '')
  return `${who ? `${who.last_name}, ${who.first_name}` : 'Someone'} — ${fn?.name ?? 'a job function'} ${when}: ${reason}.`
}

/** For actions that save pending edits first: that save failed, why, and that nothing was lost. */
const saveFailedMessage = (whatDidNotHappen: string) =>
  `Could not save your changes, so ${whatDidNotHappen}. ${saveError.value} Nothing was lost — your edits are still on screen.`

/**
 * Persist pending edits before an action that would otherwise blow them away.
 * Silent when there is nothing to save, so the CI and Clear buttons stay
 * one-click — no dialog, no "you have unsaved changes" interruption.
 */
const saveIfDirty = async (): Promise<boolean> => {
  if (!hasUnsavedChanges.value) return true
  return await saveSchedule(true)
}

// Event handler: ShiftGroupedSchedule emits this after completing an assignment in its own modal.
// Do NOT open the parent's modal - the assignment is already done. Just sync (e.g. meter bookings).
const handleAddAssignment = (_employeeId: string, _timeSlot: string) => {
  syncMeterBookings()
}

// PTO Modal state and actions
// Notification modal state
const showNotificationModal = ref(false)
const notificationMessage = ref('')
const notificationType = ref<'success' | 'error'>('success')

const showNotification = (message: string, type: 'success' | 'error' = 'success') => {
  notificationMessage.value = message
  notificationType.value = type
  showNotificationModal.value = true
}

const closeNotificationModal = () => {
  showNotificationModal.value = false
  notificationMessage.value = ''
}

const showPTOModal = ref(false)
const ptoForm = ref({
  employee_id: '',
  pto_date: '',
  full_day: true,
  start_time: '08:00',
  end_time: '17:00'
})

/** Normalize DB / form dates to YYYY-MM-DD so PTO rows match the schedule date. */
const toYMD = (d: any): string => {
  if (d == null || d === '') return ''
  if (typeof d === 'string') return d.slice(0, 10)
  if (d instanceof Date) return d.toISOString().slice(0, 10)
  return String(d).slice(0, 10)
}

/**
 * The absence this popup edits. Never a call-in: those belong to the CI button.
 * This used to pick up a call-in as "the existing absence", so Save PTO or
 * Cancel PTO silently deleted the call-in record.
 */
const resolvedPtoRecord = computed(() => {
  if (!showPTOModal.value || !ptoForm.value.employee_id) return null
  const recs = ptoByEmployeeId.value?.[ptoForm.value.employee_id] || []
  const target = toYMD(ptoForm.value.pto_date || scheduleDate.value)
  return recs.find((r: any) => toYMD(r.pto_date) === target && r.pto_type !== 'call_in') || null
})

/** A call-in the same day — shown as a note so it isn't mistaken for this absence. */
const ptoModalCallIn = computed(() => {
  if (!showPTOModal.value || !ptoForm.value.employee_id) return null
  const recs = ptoByEmployeeId.value?.[ptoForm.value.employee_id] || []
  const target = toYMD(ptoForm.value.pto_date || scheduleDate.value)
  return recs.find((r: any) => toYMD(r.pto_date) === target && r.pto_type === 'call_in') || null
})

/** This person's shift hours as "HH:MM" — the default for a partial day. */
const shiftWindowFor = (employeeId: string): { start: string; end: string } => {
  const sh = shiftForEmployee(employeeId)
  return sh?.start_time && sh?.end_time
    ? { start: sh.start_time.substring(0, 5), end: sh.end_time.substring(0, 5) }
    : { start: '08:00', end: '17:00' }
}

const openPTOModal = (employee: any) => {
  const id = employee?.id || ''
  ptoForm.value.employee_id = id
  ptoForm.value.pto_date = scheduleDate.value
  const recs = ptoByEmployeeId.value?.[id] || []
  const target = toYMD(scheduleDate.value)
  const existing = recs.find((r: any) => toYMD(r.pto_date) === target && r.pto_type !== 'call_in') || null
  const shiftWin = shiftWindowFor(id)
  const d = existing ? describePto(existing) : null

  if (d && !d.allDay) {
    // Arrive-late / leave-early are stored as running from or to midnight; show
    // that open end as the person's shift start / end instead.
    ptoForm.value.full_day = false
    ptoForm.value.start_time = d.startMin === 0 ? shiftWin.start : minutesToTime(d.startMin)
    ptoForm.value.end_time = d.endMin === MINUTES_IN_DAY ? shiftWin.end : minutesToTime(d.endMin)
  } else {
    ptoForm.value.full_day = true
    ptoForm.value.start_time = shiftWin.start
    ptoForm.value.end_time = shiftWin.end
  }
  showPTOModal.value = true
}

/**
 * The pto_days fields for what the popup says (storage conventions:
 * utils/ptoDisplay.ts). Always writes a real type — this popup used to be the
 * one place that wrote untyped rows. An arrive-late / leave-early whose fixed end
 * is left where it was stays that type, so the board still reads "LEAVES 2:00 PM".
 */
const ptoFieldsFromForm = (prior: any) => {
  const f = ptoForm.value
  if (f.full_day) return { pto_type: 'full_day', start_time: null, end_time: null }
  const win = shiftWindowFor(f.employee_id)
  if (prior?.pto_type === 'leave_early' && f.end_time === win.end) {
    return { pto_type: 'leave_early', start_time: f.start_time + ':00', end_time: null }
  }
  if (prior?.pto_type === 'arrive_late' && f.start_time === win.start) {
    return { pto_type: 'arrive_late', start_time: '00:00:00', end_time: f.end_time + ':00' }
  }
  return { pto_type: 'partial', start_time: f.start_time + ':00', end_time: f.end_time + ':00' }
}

const savePTO = async () => {
  if (!ptoForm.value.employee_id || !ptoForm.value.pto_date) return
  if (!ptoForm.value.full_day && (!ptoForm.value.start_time || !ptoForm.value.end_time)) {
    showNotification('Please provide start and end times for partial-day PTO.', 'error')
    return
  }
  if (!ptoForm.value.full_day && ptoForm.value.end_time <= ptoForm.value.start_time) {
    showNotification('The end time must be after the start time.', 'error')
    return
  }
  const prior = resolvedPtoRecord.value
  if (prior?.id) {
    const removed = await deletePTO(prior.id)
    if (!removed) {
      showNotification('Failed to update PTO. Please try again.', 'error')
      return
    }
  }
  const record: any = {
    employee_id: ptoForm.value.employee_id,
    pto_date: ptoForm.value.pto_date,
    ...ptoFieldsFromForm(prior),
  }
  const ok = await createPTO(record)
  if (ok) {
    await refreshAbsences()
    showPTOModal.value = false
    showNotification('PTO saved successfully.', 'success')
  } else {
    showNotification('Failed to create PTO. Please try again.', 'error')
  }
}

const closePTOModal = () => {
  showPTOModal.value = false
}

const deleteCurrentPTO = async () => {
  const rec = resolvedPtoRecord.value
  if (!rec?.id) return
  const ok = await deletePTO(rec.id)
  if (ok) {
    await refreshAbsences()
    showPTOModal.value = false
    showNotification('PTO removed.', 'success')
  } else {
    showNotification('Failed to remove PTO. Please try again.', 'error')
  }
}

// Call-In Modal state and actions (stored as pto_days with pto_type='call_in')
const showCallInModal = ref(false)
const callInForm = ref({
  employee_id: '',
  pto_date: '',
  notes: ''
})

const resolvedCallInRecord = computed(() => {
  if (!showCallInModal.value || !callInForm.value.employee_id) return null
  const recs = ptoByEmployeeId.value?.[callInForm.value.employee_id] || []
  const target = toYMD(callInForm.value.pto_date || scheduleDate.value)
  return recs.find((r: any) => toYMD(r.pto_date) === target && r.pto_type === 'call_in') || null
})

const openCallInModal = (employee: any) => {
  callInForm.value.employee_id = employee?.id || ''
  callInForm.value.pto_date = scheduleDate.value
  const recs = ptoByEmployeeId.value?.[employee?.id || ''] || []
  const target = toYMD(scheduleDate.value)
  const existing = recs.find((r: any) => toYMD(r.pto_date) === target && r.pto_type === 'call_in') || null
  callInForm.value.notes = existing?.notes || ''
  showCallInModal.value = true
}

// Delete every schedule assignment for one employee on a given date. Used by call-in:
// a called-in employee isn't working, so their day is wiped clean.
const clearEmployeeAssignmentsForDate = async (employeeId: string, date: string): Promise<number> => {
  let list: any[] = []
  try {
    list = await $fetch<any[]>(`/api/schedule/${date}`)
  } catch {
    list = []
  }
  const mine = (Array.isArray(list) ? list : []).filter((a: any) => a.employee_id === employeeId && a.id)
  for (const a of mine) {
    await deleteAssignment(a.id)
  }
  return mine.length
}

/**
 * Delete every assignment one person has on `date`, and blank their row if that
 * is the day on screen — everyone else's rows are left exactly as they are.
 * Call-in, Clear All Functions and shift swaps all go through here. Callers run
 * saveIfDirty() first: the refetch below rebuilds the grid from the server.
 */
const wipeEmployeeDay = async (employeeId: string, date: string): Promise<number> => {
  const cleared = await clearEmployeeAssignmentsForDate(employeeId, date)
  if (toYMD(date) === toYMD(scheduleDate.value)) {
    await fetchScheduleForDate(scheduleDate.value)
    scheduleAssignmentsData.value = { ...scheduleAssignmentsData.value, [employeeId]: {} }
    markGridSaved()
    await nextTick()
    syncMeterBookings()
  }
  return cleared
}

const saveCallIn = async () => {
  if (!callInForm.value.employee_id || !callInForm.value.pto_date) return

  // Persist any in-progress edits FIRST. Recording a call-in used to refetch the
  // day and rebuild the grid, silently discarding everything the user hadn't
  // saved yet. Folding the save into this action keeps it one click.
  const hadPendingEdits = hasUnsavedChanges.value
  if (!(await saveIfDirty())) {
    showNotification(saveFailedMessage('the call-in was not recorded'), 'error')
    return
  }

  const prior = resolvedCallInRecord.value
  if (prior?.id) {
    const removed = await deletePTO(prior.id)
    if (!removed) {
      showNotification('Failed to update call-in. Please try again.', 'error')
      return
    }
  }
  const ok = await createPTO({
    employee_id: callInForm.value.employee_id,
    pto_date: callInForm.value.pto_date,
    start_time: null,
    end_time: null,
    pto_type: 'call_in',
    notes: callInForm.value.notes || null
  })
  if (ok) {
    // A call-in clears that employee's entire day — wipe all their assignments.
    const cleared = await wipeEmployeeDay(callInForm.value.employee_id, callInForm.value.pto_date)
    await refreshAbsences()
    showCallInModal.value = false
    showNotification(
      [
        hadPendingEdits ? 'Your changes were saved.' : null,
        cleared > 0 ? `Call-in saved and ${cleared} assignment(s) cleared.` : 'Call-in saved.',
      ].filter(Boolean).join(' '),
      'success'
    )
  } else {
    showNotification('Failed to save call-in. Please try again.', 'error')
  }
}

const closeCallInModal = () => {
  showCallInModal.value = false
}

// "Clear All Functions" from the assignment modal — hard-wipe an employee's day.
const handleClearEmployee = async (employee: any) => {
  if (!employee?.id) return
  const name = `${employee.last_name || ''}, ${employee.first_name || ''}`.replace(/^,\s*/, '')

  // Same hazard as the call-in: this used to rebuild the grid and discard
  // unsaved work for everyone else. Save first, then clear just this row.
  const hadPendingEdits = hasUnsavedChanges.value
  if (!(await saveIfDirty())) {
    showNotification(saveFailedMessage(`${name} was not cleared`), 'error')
    return
  }

  const cleared = await wipeEmployeeDay(employee.id, scheduleDate.value)
  showNotification(
    [
      hadPendingEdits ? 'Your changes were saved.' : null,
      cleared > 0 ? `Cleared ${cleared} assignment(s) for ${name}.` : `${name} had no assignments to clear.`,
    ].filter(Boolean).join(' '),
    'success'
  )
}

const deleteCurrentCallIn = async () => {
  const rec = resolvedCallInRecord.value
  if (!rec?.id) return
  const ok = await deletePTO(rec.id)
  if (ok) {
    await refreshAbsences()
    showCallInModal.value = false
    showNotification('Call-in removed.', 'success')
  } else {
    showNotification('Failed to remove call-in. Please try again.', 'error')
  }
}

// Shift Swap Modal state and actions
const showShiftSwapModal = ref(false)
const selectedSwapEmployee = ref<any>(null)
const shiftSwapForm = ref({
  employee_id: '',
  swap_date: '',
  original_shift_id: '',
  swapped_shift_id: '',
  notes: ''
})
const existingShiftSwap = computed(() => {
  if (!selectedSwapEmployee.value || !scheduleDate.value) return null
  return getSwapForEmployee(selectedSwapEmployee.value.id, scheduleDate.value)
})

const openShiftSwapModal = (employee: any) => {
  selectedSwapEmployee.value = employee
  const swap = getSwapForEmployee(employee?.id || '', scheduleDate.value)
  shiftSwapForm.value.employee_id = employee?.id || ''
  shiftSwapForm.value.swap_date = scheduleDate.value
  shiftSwapForm.value.original_shift_id = employee?.shift_id || ''
  shiftSwapForm.value.swapped_shift_id = swap?.swapped_shift_id || ''
  shiftSwapForm.value.notes = swap?.notes || ''
  showShiftSwapModal.value = true
}

/** Does the person in the swap popup have anything assigned on the day on screen? */
const swapEmployeeHasAssignments = computed(() => {
  const row = scheduleAssignmentsData.value?.[shiftSwapForm.value.employee_id] || {}
  return Object.values(row).some((slot: any) => slot?.assignment)
})

const swapMessage = (what: string, cleared: number, hadPendingEdits: boolean, reassignOn: string) =>
  [
    hadPendingEdits ? 'Your changes were saved.' : null,
    what,
    cleared > 0 ? `${cleared} assignment(s) were cleared — assign them on ${reassignOn}.` : null,
  ].filter(Boolean).join(' ')

/**
 * A swap moves someone to another shift's hours, so assignments made for their
 * old shift are cleared for that day, the same as a call-in. Left in place they
 * sat hidden outside the new shift's window and were still saved. A save that only
 * changes the notes leaves the day alone.
 */
const saveShiftSwap = async () => {
  const f = shiftSwapForm.value
  if (!f.employee_id || !f.swap_date || !f.swapped_shift_id) return

  const shiftChanges =
    toYMD(f.swap_date) !== toYMD(scheduleDate.value) ||
    existingShiftSwap.value?.swapped_shift_id !== f.swapped_shift_id
  const hadPendingEdits = hasUnsavedChanges.value
  if (shiftChanges && !(await saveIfDirty())) {
    showNotification(saveFailedMessage('the shift swap was not saved'), 'error')
    return
  }

  const saved = await createShiftSwap({
    employee_id: f.employee_id,
    swap_date: f.swap_date,
    original_shift_id: f.original_shift_id,
    swapped_shift_id: f.swapped_shift_id,
    notes: f.notes || null
  })
  // createShiftSwap reports failure by returning null, not by throwing — this
  // used to close the popup as if it had worked.
  if (!saved) {
    showNotification('Failed to save shift swap. Please try again.', 'error')
    return
  }

  const cleared = shiftChanges ? await wipeEmployeeDay(f.employee_id, f.swap_date) : 0
  // A swap changes which shift their time off is priced against, so re-read the hours too.
  await Promise.all([fetchShiftSwapsForDate(scheduleDate.value), loadPtoUsed()])
  showShiftSwapModal.value = false
  if (shiftChanges) {
    showNotification(swapMessage('Shift swap saved.', cleared, hadPendingEdits, 'the new shift'), 'success')
  }
}

/** Removing a swap puts them back on their own shift — clear the swapped-shift day too. */
const deleteShiftSwap = async () => {
  const swap = existingShiftSwap.value
  if (!swap?.id) return

  const hadPendingEdits = hasUnsavedChanges.value
  if (!(await saveIfDirty())) {
    showNotification(saveFailedMessage('the shift swap was not removed'), 'error')
    return
  }

  const ok = await deleteShiftSwapAction(swap.id)
  if (!ok) {
    showNotification('Failed to delete shift swap. Please try again.', 'error')
    return
  }

  const cleared = await wipeEmployeeDay(swap.employee_id, scheduleDate.value)
  // A swap changes which shift their time off is priced against, so re-read the hours too.
  await Promise.all([fetchShiftSwapsForDate(scheduleDate.value), loadPtoUsed()])
  showShiftSwapModal.value = false
  showNotification(swapMessage('Shift swap removed.', cleared, hadPendingEdits, 'their usual shift'), 'success')
}

const closeShiftSwapModal = () => {
  showShiftSwapModal.value = false
}

const getShiftName = (shiftId: string) => {
  const shift = scheduleData.value.find((s: any) => s.id === shiftId)
  return shift?.name || 'Unknown Shift'
}

/**
 * The day's 15-minute slots ("HH:MM"), from the earliest active shift start to the
 * latest shift end, as entered in Team Setup → Shift Management. Add a 6AM shift and
 * the day starts at 6AM everywhere on this page.
 *
 * Save and the dashboards both read this one list. The dashboards used to run a
 * hardcoded 8AM–8PM, which hid the 7AM shift's first hour and the last half hour of
 * the 8:30PM shifts.
 */
const daySlots = computed<string[]>(() => {
  const list = (shifts.value || []).filter((s: any) => s?.start_time && s?.end_time)
  if (list.length === 0) return []
  const minStart = Math.min(...list.map((s: any) => timeToMinutes(s.start_time.substring(0, 5))))
  const maxEnd = Math.max(...list.map((s: any) => timeToMinutes(s.end_time.substring(0, 5))))
  const slots: string[] = []
  for (let m = minStart; m < maxEnd; m += 15) {
    slots.push(minutesToTime(m))
  }
  return slots
})

// Dashboard columns — the same slots as Save, so the two can't disagree.
const meterTimeSlots = computed(() => daySlots.value.map((time) => ({ time })))

const formatTimeForMeterDashboard = (time: string): string => {
  const [hours, minutes] = time.split(':').map(Number)
  
  // Only show time labels for hourly slots (when minutes === 0)
  if (minutes === 0) {
    const period = hours >= 12 ? 'PM' : 'AM'
    const displayHours = hours > 12 ? hours - 12 : (hours === 0 ? 12 : hours)
    return `${displayHours} ${period}`
  }
  
  // Return empty string for non-hourly slots
  return ''
}

const isHourlyMarker = (time: string): boolean => {
  const [hours, minutes] = time.split(':').map(Number)
  return minutes === 0
}

// Active meter stations are derived from the live job_functions list so the
// dashboard stays in sync with whatever "Meter N" rows exist in the DB.
// Delete a Meter in the Job Functions UI → its row disappears here automatically.
const ACTIVE_METER_NUMBERS = computed<number[]>(() => {
  const nums = new Set<number>()
  for (const jf of jobFunctions.value || []) {
    if (jf?.is_active === false) continue
    const m = /^Meter (\d+)$/.exec(jf?.name || '')
    if (m && m[1]) nums.add(parseInt(m[1], 10))
  }
  return Array.from(nums).sort((a, b) => a - b)
})

const isMeterBooked = (meterNumber: number, timeSlot: string): boolean => {
  const key = `meter-${meterNumber}-${timeSlot}`
  return (meterBookings.value[key] || 0) > 0
}

// Check if a meter is double-booked (booked more than once)
const isMeterDoubleBooked = (meterNumber: number, timeSlot: string): boolean => {
  const key = `meter-${meterNumber}-${timeSlot}`
  return (meterBookings.value[key] || 0) > 1
}

const getMeterSlotClasses = (meterNumber: number, timeSlot: string): string => {
  const isBooked = isMeterBooked(meterNumber, timeSlot)
  const isDoubleBooked = isMeterDoubleBooked(meterNumber, timeSlot)
  
  if (isDoubleBooked) {
    return 'shadow-md ring-2 ring-red-500 ring-opacity-75'
  }
  
  return isBooked 
    ? 'shadow-sm' 
    : ''
}

const getMeterSlotStyle = (meterNumber: number, timeSlot: string): Record<string, string> => {
  // Check if this specific 15-minute time slot is booked
  const isBooked = isMeterBooked(meterNumber, timeSlot)
  // Check if this specific 15-minute time slot is double-booked (count > 1)
  const isDoubleBooked = isMeterDoubleBooked(meterNumber, timeSlot)
  
  if (!isBooked) return {}
  
  // If double-booked, use red background - ONLY for this specific time slot
  if (isDoubleBooked) {
    return {
      backgroundColor: '#DC2626', // Red-600
      color: '#ffffff'
    }
  }
  
  // Get the meter color from job functions for normal bookings (count === 1)
  const meterJobFunction = jobFunctions.value?.find(jf => jf.name === `Meter ${meterNumber}`)
  const meterColor = meterJobFunction?.color_code || '#87CEEB' // Default meter color
  
  return {
    backgroundColor: meterColor,
    color: '#ffffff'
  }
}

// Get employees assigned to a specific job function
const getEmployeesForJobFunction = (jobFunctionKey: string) => {
  if (!employees.value || !scheduleAssignmentsData.value) return []
  
  const jobFunctionName = jobFunctionKey
  const assignedEmployees = new Set<string>()
  
  // Find all employees who have assignments to this job function
  Object.entries(scheduleAssignmentsData.value).forEach(([employeeId, employeeSchedule]: [string, any]) => {
    Object.entries(employeeSchedule).forEach(([timeSlot, data]: [string, any]) => {
      if (data && data.assignment) {
        // Check if assignment matches the job function (case-insensitive)
        const assignment = String(data.assignment).toLowerCase().trim()
        const targetName = jobFunctionName.toLowerCase().trim()
        
        // For Meter, allow variations like "Meter 1", "Meter 2", etc.
        if (targetName === 'meter') {
          if (assignment === 'meter' || assignment.startsWith('meter ')) {
            assignedEmployees.add(employeeId)
          }
        } else {
          // For all other job functions, use exact matching to avoid confusion
          // e.g., "Pick" should NOT match "RT Pick", "DG Pick", etc.
          if (assignment === targetName) {
            assignedEmployees.add(employeeId)
          }
        }
      }
    })
  })
  
  // Return employees in sorted order
  return employees.value
    .filter((e: any) => assignedEmployees.has(e.id))
    .sort((a: any, b: any) => {
      // Sort by last name, then first name
      if (a.last_name !== b.last_name) {
        return a.last_name.localeCompare(b.last_name)
      }
      return a.first_name.localeCompare(b.first_name)
    })
}

// Is this time slot inside the employee's shift break/lunch window? Driven by the
// shift's break/lunch times (Team Setup → Shift Management), independent of
// the assignment data — so breaks always show in the dashboard even when an
// assignment block happens to span them.
const isEmployeeOnBreak = (employeeId: string, timeSlot: string): boolean => {
  const shift = shiftForEmployee(employeeId)
  if (!shift) return false
  const t = timeToMinutesHelper(timeSlot)
  const within = (start: any, end: any) =>
    !!start && !!end && t >= timeToMinutesHelper(start) && t < timeToMinutesHelper(end)
  return (
    within(shift.break_1_start, shift.break_1_end) ||
    within(shift.break_2_start, shift.break_2_end) ||
    within(shift.lunch_start, shift.lunch_end)
  )
}

// Check if employee is assigned to job function at a specific time slot
const isEmployeeAssignedToJobFunction = (employeeId: string, timeSlot: string, jobFunctionKey: string): boolean => {
  if (!scheduleAssignmentsData.value || !scheduleAssignmentsData.value[employeeId]) return false

  // A slot inside the employee's break/lunch is never "working" the function, even if
  // an assignment block spans it.
  if (isEmployeeOnBreak(employeeId, timeSlot)) return false

  const employeeSchedule = scheduleAssignmentsData.value[employeeId]
  const assignment = employeeSchedule[timeSlot]

  if (!assignment || !assignment.assignment) return false
  
  const jobFunctionName = jobFunctionKey
  const assignmentName = String(assignment.assignment).toLowerCase().trim()
  const targetName = jobFunctionName.toLowerCase().trim()
  
  // For Meter, allow variations like "Meter 1", "Meter 2", etc.
  if (targetName === 'meter') {
    return assignmentName === 'meter' || assignmentName.startsWith('meter ')
  }
  
  // For all other job functions, use exact matching to avoid confusion
  // e.g., "Pick" should NOT match "RT Pick", "DG Pick", etc.
  return assignmentName === targetName
}

// Helper function to convert time to minutes
const timeToMinutesHelper = (time: string): number => {
  const parts = time.split(':').map(Number)
  return (parts[0] || 0) * 60 + (parts[1] || 0)
}

// Get slot classes for job function dashboard
const getJobFunctionSlotClasses = (employeeId: string, timeSlot: string, jobFunctionKey: string): string => {
  const isAssigned = isEmployeeAssignedToJobFunction(employeeId, timeSlot, jobFunctionKey)
  return isAssigned ? 'shadow-sm' : ''
}

// Get slot style for job function dashboard
const getJobFunctionSlotStyle = (employeeId: string, timeSlot: string, jobFunctionKey: string): Record<string, string> => {
  const isAssigned = isEmployeeAssignedToJobFunction(employeeId, timeSlot, jobFunctionKey)
  if (!isAssigned) return {}
  
  // Get the job function color
  const jobFunctionName = jobFunctionKey
  const jobFunction = jobFunctions.value?.find(jf => 
    jf.name.toLowerCase() === jobFunctionName.toLowerCase()
  )
  
  const jobColor = jobFunction?.color_code || '#3B82F6'
  
  return {
    backgroundColor: jobColor,
    color: '#ffffff'
  }
}

// Sync meter bookings with actual schedule assignments
const syncMeterBookings = () => {
  
  // Clear existing bookings
  meterBookings.value = {}
  
  // Track processed assignment ranges to avoid double-counting the same assignment
  // Key format: `${employeeId}-${meterAssignment}-${startTime}-${endTime}`
  const processedRanges = new Set<string>()
  
  // Get all meter assignments from schedule data
  if (scheduleAssignmentsData.value) {
    Object.entries(scheduleAssignmentsData.value).forEach(([employeeId, employeeSchedule]: [string, any]) => {
      if (!employeeSchedule) return
      
      // Collect all unique assignment ranges first
      const assignmentRanges = new Map<string, { meterNumber: number; startTime: string; endTime: string }>()
      
      // Find the start of each contiguous assignment range
      Object.entries(employeeSchedule).forEach(([timeSlot, data]: [string, any]) => {
        if (data && data.assignment && data.assignment.startsWith('Meter ')) {
          const meterNumber = parseInt(data.assignment.split(' ')[1])
          
          if (ACTIVE_METER_NUMBERS.value.includes(meterNumber)) {
            const startTime = timeSlot
            const endTime = data.until
            
            // Check if this is the start of a new assignment range
            // Look at the previous time slot
            const prevSlotMinutes = timeToMinutes(timeSlot) - 15
            const prevSlot = prevSlotMinutes >= 0 ? minutesToTime(prevSlotMinutes) : null
            const prevData = prevSlot ? employeeSchedule[prevSlot] : null
            
            // This is the start of an assignment if:
            // 1. No previous slot exists
            // 2. Previous slot has no assignment
            // 3. Previous slot has a different assignment
            // 4. Previous slot has a different end time (assignment ended)
            const isStartOfAssignment = !prevData || 
                                        !prevData.assignment || 
                                        !prevData.assignment.startsWith('Meter ') ||
                                        parseInt(prevData.assignment.split(' ')[1]) !== meterNumber ||
                                        prevData.until !== endTime
            
            if (isStartOfAssignment && startTime && endTime) {
              const rangeKey = `${employeeId}-${data.assignment}-${startTime}-${endTime}`
              if (!assignmentRanges.has(rangeKey)) {
                assignmentRanges.set(rangeKey, { meterNumber, startTime, endTime })
              }
            }
          }
        }
      })
      
      // Now process each unique assignment range exactly once
      assignmentRanges.forEach((range, rangeKey) => {
        // Generate all 15-minute slots between start and end time
        const startMinutes = timeToMinutes(range.startTime)
        const endMinutes = timeToMinutes(range.endTime)
        
        let currentMinutes = startMinutes
        while (currentMinutes < endMinutes) {
          const timeString = minutesToTime(currentMinutes)
          const key = `meter-${range.meterNumber}-${timeString}`
          // Increment count - this tracks double-bookings (when multiple employees book same meter at same time)
          meterBookings.value[key] = (meterBookings.value[key] || 0) + 1
          currentMinutes += 15
        }
      })
    })
  }
  
  // Log any double-bookings for debugging
  const doubleBookings = Object.entries(meterBookings.value).filter(([_, count]) => count > 1)
  if (doubleBookings.length > 0) {
    console.warn('⚠️ Double-booked meters detected:', doubleBookings)
  }
}



// Watch for changes in schedule assignments and update schedule data
watch(scheduleAssignments, () => {
  initializeScheduleData()
}, { deep: true })

// Watch for changes in schedule data and sync meter bookings
watch(scheduleAssignmentsData, () => {
  syncMeterBookings()
}, { deep: true })

// Warn before leaving with work at risk — either a save in flight, or edits that
// were never saved. The old guard only covered the in-flight case, so closing the
// tab mid-edit lost everything without a word.
//
// Note the handler is a named reference: the previous version passed a fresh
// arrow function to both add and remove, so removeEventListener never matched and
// the listener leaked on every visit to this page.
const handleBeforeUnload = (e: BeforeUnloadEvent) => {
  if (isSaving.value) {
    e.preventDefault()
    e.returnValue = 'Schedule is currently saving. Are you sure you want to leave?'
  } else if (hasUnsavedChanges.value) {
    e.preventDefault()
    e.returnValue = 'You have unsaved schedule changes. Leave without saving?'
  }
}

onMounted(() => {
  window.addEventListener('beforeunload', handleBeforeUnload)
})

onUnmounted(() => {
  window.removeEventListener('beforeunload', handleBeforeUnload)
})

// In-app navigation bypasses beforeunload entirely, so the router asks instead.
// Leaving the page (Back to Home) is a route LEAVE; switching dates (picker, Today /
// Yesterday / Tomorrow, the browser's Back between days) is a route UPDATE — same
// page, new date — which the old leave-only guard never saw.
const confirmDiscard = () =>
  !hasUnsavedChanges.value || window.confirm('You have unsaved schedule changes. Leave without saving?')
onBeforeRouteLeave(confirmDiscard)
onBeforeRouteUpdate((to, from) => to.params.date === from.params.date || confirmDiscard())

</script>

<style scoped>
</style>