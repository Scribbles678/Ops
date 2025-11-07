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
              <div class="text-[10px] text-gray-600">Employees</div>
            </div>
            <div class="rounded border border-gray-200 bg-white px-2 py-1 text-center">
              <div class="text-xs font-bold text-green-600">{{ totalLaborHours }}h</div>
              <div class="text-[10px] text-gray-600">Labor Hours</div>
            </div>
            <div class="rounded border border-gray-200 bg-white px-2 py-1 text-center">
              <div class="text-xs font-bold text-purple-600">{{ totalShifts }}</div>
              <div class="text-[10px] text-gray-600">Active Shifts</div>
            </div>
            <div class="rounded border border-gray-200 bg-white px-2 py-1 text-center">
              <div class="text-xs font-bold text-orange-600">{{ unassignedEmployees }}</div>
              <div class="text-[10px] text-gray-600">Unassigned</div>
            </div>
            <div class="rounded border border-gray-200 bg-white px-2 py-1 text-center">
              <div class="text-xs font-bold text-red-600">{{ totalPTOHours }}</div>
              <div class="text-[10px] text-gray-600">PTO Hours</div>
            </div>
          </div>
        </div>
        <div class="flex space-x-2">
          <button 
            @click="saveSchedule" 
            :disabled="isSaving"
            class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed flex items-center text-sm px-3 py-1.5"
          >
            <svg v-if="isSaving" class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {{ isSaving ? 'Saving...' : 'Save Schedule' }}
          </button>
          <button @click="handleLogout" class="bg-red-600 hover:bg-red-700 text-white px-3 py-1.5 rounded-lg text-sm font-medium transition-colors">
            Logout
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
                  v-model="scheduleDate"
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
                <strong>Selected:</strong> 
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

        <!-- Job Function Hours Breakdown / Dashboards (Right Side) -->
        <div class="flex-1" :style="{ maxWidth: activeDashboard !== 'jobFunctions' ? `${112 + (meterTimeSlots.length * 24)}px` : 'none' }">
          <div class="card mb-0 h-full">
            <div class="flex items-center mb-2 p-2">
              <div class="flex flex-wrap gap-1.5">
                <button 
                  @click="activeDashboard = 'jobFunctions'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'jobFunctions' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  Job Functions
                </button>
                <button 
                  @click="activeDashboard = 'meter'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'meter' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  Meter
                </button>
                <button 
                  @click="activeDashboard = 'locus'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'locus' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  Locus
                </button>
                <button 
                  @click="activeDashboard = 'pick'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'pick' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  Pick
                </button>
                <button 
                  @click="activeDashboard = 'x4'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'x4' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  X4
                </button>
                <button 
                  @click="activeDashboard = 'em9'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'em9' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  EM9
                </button>
                <button 
                  @click="activeDashboard = 'speedcell'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'speedcell' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  Speedcell
                </button>
                <button 
                  @click="activeDashboard = 'helpdesk'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'helpdesk' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  Helpdesk
                </button>
                <button 
                  @click="activeDashboard = 'rtPick'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'rtPick' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  RT Pick
                </button>
                <button 
                  @click="activeDashboard = 'projects'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'projects' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  Projects
                </button>
                <button 
                  @click="activeDashboard = 'dgPick'"
                  class="px-1.5 py-0.5 text-[10px] rounded border transition-colors"
                  :class="activeDashboard === 'dgPick' ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
                >
                  DG Pick
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
                    {{ activeDashboard === 'meter' ? 'Meter' : getDashboardLabel(activeDashboard) }}
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
                      v-for="meterNumber in 20"
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
                          :class="getJobFunctionSlotClasses(employee.id, timeSlot.time, activeDashboard)"
                          :style="getJobFunctionSlotStyle(employee.id, timeSlot.time, activeDashboard)"
                        >
                          <span 
                            v-if="isEmployeeAssignedToJobFunction(employee.id, timeSlot.time, activeDashboard)" 
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
        <div class="min-w-max">
          <ShiftGroupedSchedule
            :employees="employees"
            :schedule-assignments="scheduleAssignments"
            :job-functions="jobFunctions"
            :shifts="scheduleData"
            :schedule-assignments-data="scheduleAssignmentsData"
            :pto-by-employee-id="ptoByEmployeeId"
            :shift-swaps-by-employee-id="swapByEmployeeId"
            :preferred-assignments-map="getPreferredAssignmentsMap()"
            @add-assignment="handleAddAssignment"
            @edit-assignment="handleEditAssignment"
            @assign-break-coverage="handleBreakCoverage"
            @schedule-data-updated="handleScheduleDataUpdated"
            @addPTO="openPTOModal"
            @addShiftSwap="openShiftSwapModal"
          />
        </div>
      </div>

      <!-- Job Function Assignment Modal -->
      <div v-if="showEmployeeModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
          <h3 class="text-xl font-bold mb-4">
            Assign Job Function to {{ selectedEmployee?.last_name || '' }}, {{ selectedEmployee?.first_name || '' }}
            <span v-if="selectedShift"> - {{ selectedShift.name }}</span>
          </h3>
          
          <!-- Available Job Functions -->
          <div class="space-y-2 mb-4">
            <h4 class="font-medium text-gray-700">Available Job Functions:</h4>
            <div class="grid grid-cols-2 md:grid-cols-3 gap-2 max-h-48 overflow-y-auto">
              <div v-for="jobFunction in availableJobFunctions" :key="jobFunction" 
                   class="flex items-center justify-between p-2 border border-gray-200 rounded hover:bg-gray-50">
                <div class="flex items-center space-x-2">
                  <div class="w-4 h-4 rounded border border-gray-300" 
                       :style="{ backgroundColor: getJobFunctionColor(jobFunction) }"></div>
                  <span class="text-sm">{{ jobFunction }}</span>
                </div>
                <button @click="assignJobFunction(jobFunction)" 
                        class="px-3 py-1 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition text-sm">
                  Assign
                </button>
              </div>
            </div>
          </div>

          <!-- Current Assignments -->
          <div v-if="selectedEmployee && selectedShift && getEmployeeAssignments(selectedEmployee.id, selectedShift.id).length > 0" class="space-y-2">
            <h4 class="font-medium text-gray-700">Current Assignments:</h4>
            <div class="space-y-1">
              <div v-for="assignment in getEmployeeAssignments(selectedEmployee.id, selectedShift.id)" :key="assignment.id" 
                   class="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div class="flex items-center space-x-2">
                  <div class="w-4 h-4 rounded" 
                       :style="{ backgroundColor: getJobFunctionColor(assignment.job_function) }"></div>
                  <span class="text-sm">{{ assignment.job_function }}</span>
                </div>
                <button @click="removeAssignment(assignment.id)" 
                        class="px-3 py-1 bg-red-100 text-red-600 rounded hover:bg-red-200 transition text-sm">
                  Remove
                </button>
              </div>
            </div>
          </div>

          <div class="flex justify-end space-x-3 pt-4">
            <button @click="closeEmployeeModal" class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
              Close
            </button>
          </div>
        </div>
      </div>

      <!-- PTO Modal -->
      <div v-if="showPTOModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 max-h-[90vh] overflow-y-auto">
          <h3 class="text-xl font-bold mb-4">Add Absence</h3>
          <div class="space-y-3">
            <div v-if="existingPTORecord" class="p-3 bg-blue-50 border border-blue-200 rounded-md text-sm text-blue-800">
              Absence already exists for this employee on {{ formatDate(scheduleDate) }}.
              Update the details below or remove it.
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
            <div class="flex justify-between gap-2 pt-2">
              <button v-if="existingPTORecord" @click="deleteCurrentPTO" class="px-4 py-2 bg-red-100 text-red-600 rounded-lg hover:bg-red-200">
                Remove PTO
              </button>
              <div class="flex gap-2 ml-auto">
                <button @click="closePTOModal" class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">Cancel</button>
                <button @click="savePTO" class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">Save PTO</button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Notification Modal -->
      <div v-if="showNotificationModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
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
  </div>
</template>

<script setup lang="ts">
// Import the component explicitly
import ShiftGroupedSchedule from '~/components/schedule/ShiftGroupedSchedule.vue'

// Supabase client
const { $supabase } = useNuxtApp()

// Use real composables instead of mock data
const { 
  employees, 
  loading: employeesLoading, 
  error: employeesError, 
  fetchEmployees 
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
  createAssignment,
  deleteAssignment
} = useSchedule()

// PTO composable
const {
  pto,
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
  fetchPreferredAssignments,
  getPreferredAssignmentsMap
} = usePreferredAssignments()

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

// Data loading
const loading = computed(() => 
  employeesLoading.value || functionsLoading.value || shiftsLoading.value || assignmentsLoading.value
)

const error = computed(() => 
  employeesError.value || functionsError.value || shiftsError.value || assignmentsError.value
)

// Modal state
const showEmployeeModal = ref(false)
const selectedEmployee = ref<any>(null)
const selectedShift = ref<any>(null)
const selectedJobFunction = ref('')
const scheduleAssignmentsData = ref<Record<string, any>>({})

// Save state
const isSaving = ref(false)
const saveProgress = ref('')

// Target hours state
const targetHours = ref({})

// Dashboard state - tracks which dashboard view is active
const activeDashboard = ref<'jobFunctions' | 'meter' | 'locus' | 'pick' | 'x4' | 'em9' | 'speedcell' | 'helpdesk' | 'rtPick' | 'projects' | 'dgPick'>('jobFunctions')
const meterBookings = ref<Record<string, number>>({}) // Changed to number to track count of bookings

// Get route params - use client-only for date to avoid hydration mismatch
const route = useRoute()
const scheduleDate = ref('')

// Initialize date on client side to avoid hydration mismatch
onMounted(async () => {
  if (!scheduleDate.value) {
    scheduleDate.value = (route.params.date as string) || getTZISODate('America/Chicago')
  }
  // Load shift swaps for the initial date
  if (scheduleDate.value) {
    await fetchShiftSwapsForDate(scheduleDate.value)
  }
})

// Helpers for local/TZ-safe ISO dates
const toLocalISO = (d: Date): string => {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const getTZISODate = (tz: string): string => {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(new Date())
}

// Date navigation functions
const goToToday = () => {
  scheduleDate.value = getTZISODate('America/Chicago')
  navigateTo(`/schedule/${scheduleDate.value}`)
}

const goToYesterday = () => {
  const d = new Date()
  d.setDate(d.getDate() - 1)
  scheduleDate.value = toLocalISO(d)
  navigateTo(`/schedule/${scheduleDate.value}`)
}

const goToTomorrow = () => {
  const d = new Date()
  d.setDate(d.getDate() + 1)
  scheduleDate.value = toLocalISO(d)
  navigateTo(`/schedule/${scheduleDate.value}`)
}

// Date status computed properties - make them hydration-safe
const isWeekend = computed(() => {
  if (!scheduleDate.value) return false
  const date = new Date(scheduleDate.value)
  const day = date.getDay()
  return day === 0 || day === 6 // Sunday or Saturday
})

const isFuture = computed(() => {
  if (!scheduleDate.value) return false
  const selectedDate = new Date(scheduleDate.value)
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return selectedDate > today
})

const isPast = computed(() => {
  if (!scheduleDate.value) return false
  const selectedDate = new Date(scheduleDate.value)
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return selectedDate < today
})

// Watch for date changes to reload schedule data
watch(scheduleDate, async (newDate) => {
  if (newDate) {
    await fetchScheduleForDate(newDate)
    await fetchPTOForDate(newDate)
    await fetchShiftSwapsForDate(newDate)
    await fetchPreferredAssignments() // Reload preferred assignments when date changes
    await nextTick()
    initializeScheduleData()
  }
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

// Target hours functions
const loadTargetHours = async () => {
  try {
    console.log('Loading target hours from database...')
    console.log('Job functions available:', jobFunctions.value.length)
    
    // First, let's check if the table exists and has any data
    const { data: allData, error: allError } = await $supabase
      .from('target_hours')
      .select('*')
    
    console.log('All target_hours table data:', allData)
    console.log('Any errors:', allError)
    
    // Load from database
    const { data, error } = await $supabase
      .from('target_hours')
      .select('job_function_id, target_hours')
    
    if (error) {
      console.error('Database error:', error)
      throw error
    }
    
    console.log('Raw target hours data from database:', data)
    
    // Convert array to object format
    const targetHoursData = {}
    if (data && data.length > 0) {
      data.forEach(item => {
        targetHoursData[item.job_function_id] = item.target_hours
        console.log(`Mapped ${item.job_function_id} -> ${item.target_hours}`)
      })
    } else {
      console.log('No target hours data found in database')
    }
    
    console.log('Converted target hours data:', targetHoursData)
    
    // Don't add default values - only use what's in the database
    console.log('Using only database values, no defaults added')
    
    targetHours.value = targetHoursData
    console.log('Final target hours loaded:', targetHours.value)
    
  } catch (error) {
    console.error('Error loading target hours:', error)
    // Don't use fallback - keep targetHours empty so we can see the issue
    targetHours.value = {}
    console.log('Error occurred, targetHours.value set to empty object')
  }
}

const getTargetHours = (jobFunctionId: string) => {
  console.log(`Getting target hours for job function ${jobFunctionId}`)
  console.log('Current targetHours.value:', targetHours.value)
  
  if (!targetHours.value || Object.keys(targetHours.value).length === 0) {
    console.log('targetHours.value is empty, returning 0')
    return 0
  }
  
  // Special handling for meter group
  if (jobFunctionId === 'meter-group') {
    // Sum up target hours for all meters
    let totalMeterHours = 0
    jobFunctions.value.forEach((job: any) => {
      if (job.name.startsWith('Meter ')) {
        const hours = targetHours.value[job.id]
        if (hours !== undefined && hours !== null) {
          totalMeterHours += hours
        }
      }
    })
    console.log(`Found total meter target hours: ${totalMeterHours}`)
    return totalMeterHours
  }
  
  const hours = targetHours.value[jobFunctionId]
  if (hours === undefined || hours === null) {
    console.log(`No target hours found for ${jobFunctionId}, returning 0`)
    return 0
  }
  
  console.log(`Found target hours for ${jobFunctionId}: ${hours}`)
  return hours
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
  console.log('Initializing schedule data...')
  console.log('Schedule assignments:', scheduleAssignments.value)
  console.log('Employees:', employees.value.length)
  console.log('Job functions:', jobFunctions.value.length)
  
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
  
  console.log('Initialized schedule data:', initialData)
  scheduleAssignmentsData.value = initialData
  console.log('scheduleAssignmentsData after initialization:', scheduleAssignmentsData.value)
}

// Load data on mount
onMounted(async () => {
  try {
    await Promise.all([
      fetchEmployees(),
      fetchJobFunctions(),
      fetchShifts(),
      fetchScheduleForDate(scheduleDate.value),
      fetchPreferredAssignments() // Load preferred assignments
    ])
    await fetchPTOForDate(scheduleDate.value)
    // Load target hours from database
    await loadTargetHours()
    
    // Initialize schedule data from existing assignments
    // Use nextTick to ensure all reactive data is updated
    await nextTick()
    initializeScheduleData()
    
    // Sync meter bookings after schedule data is initialized
    syncMeterBookings()
    
  } catch (error) {
    console.error('Error loading schedule data:', error)
  }
})

// Helper function to check if a shift is the part-time shift (4-8:30 PM)
const isPartTimeShift = (shift: any): boolean => {
  if (!shift) return false
  // Check if shift starts at 4:00 PM (16:00) and ends at 8:30 PM (20:30)
  const startTime = shift.start_time?.substring(0, 5) || '' // "HH:MM" format
  const endTime = shift.end_time?.substring(0, 5) || ''
  return startTime === '16:00' && endTime === '20:30'
}

// Helper function to check if an employee is part-time (in 4-8:30 PM shift)
const isPartTimeEmployee = (employee: any): boolean => {
  if (!employee) return false
  
  // Account for shift swaps
  const swap = swapByEmployeeId.value?.[employee.id]
  const actualShiftId = swap ? swap.swapped_shift_id : employee.shift_id
  
  if (!actualShiftId) return false
  
  const shift = scheduleData.value.find((s: any) => s.id === actualShiftId)
  return isPartTimeShift(shift)
}

// Helper function to get employee count (0.5 for part-time, 1 for full-time)
const getEmployeeCount = (employee: any): number => {
  return isPartTimeEmployee(employee) ? 0.5 : 1
}

// Computed properties
const totalEmployees = computed(() => {
  if (!employees.value) return 0
  
  // Sum up employee counts: 0.5 for part-time (4-8:30 PM), 1 for full-time
  return employees.value.reduce((total: number, employee: any) => {
    return total + getEmployeeCount(employee)
  }, 0)
})

const totalLaborHours = computed(() => {
  if (!employees.value || !scheduleData.value) return 0
  
  // Calculate total working hours based on shift hours, excluding PTO and lunch
  let totalHours = 0
  
  employees.value.forEach((employee: any) => {
    // Skip employees on PTO for this day
    if (ptoByEmployeeId.value && ptoByEmployeeId.value[employee.id] && ptoByEmployeeId.value[employee.id].length > 0) {
      return // Skip this employee
    }
    
    // Get employee's shift (accounting for shift swaps)
    const swap = swapByEmployeeId.value?.[employee.id]
    const actualShiftId = swap ? swap.swapped_shift_id : employee.shift_id
    
    if (!actualShiftId) return // Skip employees without a shift
    
    const shift = scheduleData.value.find((s: any) => s.id === actualShiftId)
    if (!shift || !shift.start_time || !shift.end_time) return
    
    // Calculate shift hours from start_time to end_time
    const shiftStartMinutes = timeToMinutes(shift.start_time.substring(0, 5))
    const shiftEndMinutes = timeToMinutes(shift.end_time.substring(0, 5))
    let shiftTotalMinutes = shiftEndMinutes - shiftStartMinutes
    
    // Subtract lunch time (unpaid) if it exists
    if (shift.lunch_start && shift.lunch_end) {
      const lunchStartMinutes = timeToMinutes(shift.lunch_start.substring(0, 5))
      const lunchEndMinutes = timeToMinutes(shift.lunch_end.substring(0, 5))
      
      // Only subtract lunch if it falls within the shift
      if (lunchStartMinutes >= shiftStartMinutes && lunchEndMinutes <= shiftEndMinutes) {
        shiftTotalMinutes -= (lunchEndMinutes - lunchStartMinutes)
      }
    }
    
    // Convert minutes to hours
    const employeeHours = shiftTotalMinutes / 60
    
    // Factor in part-time multiplier (0.5 for part-time employees)
    const multiplier = isPartTimeEmployee(employee) ? 0.5 : 1
    totalHours += employeeHours * multiplier
  })
  
  return Math.round(totalHours * 10) / 10
})

const totalShifts = computed(() => {
  return shifts.value.length
})

const unassignedEmployees = computed(() => {
  if (!scheduleAssignments.value || !employees.value) return 0
  
  const assignedEmployeeIds = new Set(scheduleAssignments.value.map((a: any) => a.employee_id))
  
  // Sum up unassigned employee counts: 0.5 for part-time, 1 for full-time
  return employees.value
    .filter((e: any) => !assignedEmployeeIds.has(e.id))
    .reduce((total: number, employee: any) => {
      return total + getEmployeeCount(employee)
    }, 0)
})

const totalPTOHours = computed(() => {
  if (!pto.value || pto.value.length === 0 || !employees.value || !scheduleData.value) return 0
  
  let totalHours = 0
  
  // Process each PTO record
  pto.value.forEach((ptoRecord: any) => {
    const employee = employees.value.find((e: any) => e.id === ptoRecord.employee_id)
    if (!employee) return
    
    // Get employee's shift (accounting for shift swaps)
    const swap = swapByEmployeeId.value?.[employee.id]
    const actualShiftId = swap ? swap.swapped_shift_id : employee.shift_id
    
    if (!actualShiftId) return
    
    const shift = scheduleData.value.find((s: any) => s.id === actualShiftId)
    if (!shift) return
    
    let ptoHours = 0
    
    // Check if it's full day PTO (no start_time or end_time)
    if (!ptoRecord.start_time && !ptoRecord.end_time) {
      // Full day PTO: use shift hours (excluding lunch)
      const shiftStartMinutes = timeToMinutes(shift.start_time.substring(0, 5))
      const shiftEndMinutes = timeToMinutes(shift.end_time.substring(0, 5))
      let shiftTotalMinutes = shiftEndMinutes - shiftStartMinutes
      
      // Subtract lunch time (unpaid) if it exists
      if (shift.lunch_start && shift.lunch_end) {
        const lunchStartMinutes = timeToMinutes(shift.lunch_start.substring(0, 5))
        const lunchEndMinutes = timeToMinutes(shift.lunch_end.substring(0, 5))
        
        // Only subtract lunch if it falls within the shift
        if (lunchStartMinutes >= shiftStartMinutes && lunchEndMinutes <= shiftEndMinutes) {
          shiftTotalMinutes -= (lunchEndMinutes - lunchStartMinutes)
        }
      }
      
      ptoHours = shiftTotalMinutes / 60
    } else {
      // Partial day PTO: calculate hours between start_time and end_time
      const ptoStartMinutes = ptoRecord.start_time ? timeToMinutes(ptoRecord.start_time.substring(0, 5)) : 0
      const ptoEndMinutes = ptoRecord.end_time ? timeToMinutes(ptoRecord.end_time.substring(0, 5)) : 0
      
      if (ptoStartMinutes >= 0 && ptoEndMinutes > ptoStartMinutes) {
        let ptoTotalMinutes = ptoEndMinutes - ptoStartMinutes
        
        // Subtract lunch time if it falls within the PTO period
        if (shift.lunch_start && shift.lunch_end) {
          const lunchStartMinutes = timeToMinutes(shift.lunch_start.substring(0, 5))
          const lunchEndMinutes = timeToMinutes(shift.lunch_end.substring(0, 5))
          
          // Calculate overlap between PTO period and lunch period
          const overlapStart = Math.max(ptoStartMinutes, lunchStartMinutes)
          const overlapEnd = Math.min(ptoEndMinutes, lunchEndMinutes)
          
          if (overlapEnd > overlapStart) {
            // There's overlap - subtract the overlapping lunch time
            ptoTotalMinutes -= (overlapEnd - overlapStart)
          }
        }
        
        ptoHours = ptoTotalMinutes / 60
      }
    }
    
    // Factor in part-time multiplier (0.5 for part-time employees)
    const multiplier = isPartTimeEmployee(employee) ? 0.5 : 1
    totalHours += ptoHours * multiplier
  })
  
  return Math.round(totalHours * 10) / 10
})

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

const getEmployeeAssignment = (employeeId: string, timeBlock: string) => {
  if (!scheduleAssignments.value) return null
  return scheduleAssignments.value.find((a: any) => 
    a.employee_id === employeeId && a.shift_id === timeBlock
  )
}

const getEmployeeAssignments = (employeeId: string, shiftId: string) => {
  if (!scheduleAssignments.value) return []
  return scheduleAssignments.value.filter((a: any) => 
    a.employee_id === employeeId && a.shift_id === shiftId
  )
}

const getEmployeesForShiftAndJob = (shiftId: string, jobFunction: string) => {
  if (!scheduleAssignments.value || !employees.value) return []
  const assignments = scheduleAssignments.value.filter((a: any) => 
    a.shift_id === shiftId && a.job_function === jobFunction
  )
  return assignments.map((assignment: any) => 
    employees.value.find((e: any) => e.id === assignment.employee_id)
  ).filter(Boolean)
}

const getTotalEmployeesForShift = (shiftId: string) => {
  if (!scheduleAssignments.value) return 0
  return scheduleAssignments.value.filter((a: any) => a.shift_id === shiftId).length
}

const getJobFunctionColor = (jobFunctions: string) => {
  const colors: Record<string, string> = {
    'RT Pick': '#FFA500',
    'Pick': '#FFFF00',
    'Meter': '#87CEEB',
    'Locus': '#FFD700', // Gold color for better visibility
    'Helpdesk': '#FFD700',
    'Coordinator': '#C0C0C0',
    'Team Lead': '#000080'
  }
  return colors[jobFunctions] || '#3B82F6'
}

const addAssignmentToEmployee = (employeeId: string, shiftId: string) => {
  selectedEmployee.value = employees.value.find((e: any) => e.id === employeeId) || null
  selectedShift.value = scheduleData.value.find((s: any) => s.id === shiftId) || null
  showEmployeeModal.value = true
}

const addEmployeeToShift = (shiftId: string, jobFunction: string) => {
  selectedShift.value = scheduleData.value.find((s: any) => s.id === shiftId) || null
  selectedJobFunction.value = jobFunction
  showEmployeeModal.value = true
}

const availableJobFunctions = computed(() => {
  if (!selectedEmployee.value) return []
  
  // Get job functions the employee is trained for
  return (selectedEmployee.value as any).trained_job_functions || []
})

const availableEmployees = computed(() => {
  if (!selectedShift.value || !selectedJobFunction.value || !scheduleAssignments.value || !employees.value) return []
  
  const assignedEmployeeIds = scheduleAssignments.value
    .filter((a: any) => a.shift_id === (selectedShift.value as any).id)
    .map((a: any) => a.employee_id)
  
  return employees.value.filter((employee: any) => 
    !assignedEmployeeIds.includes(employee.id) && 
    employee.trained_job_functions.includes(selectedJobFunction.value)
  )
})

const assignJobFunction = (jobFunction: string) => {
  if (!scheduleAssignments.value || !selectedEmployee.value || !selectedShift.value) return
  
  scheduleAssignments.value.push({
    id: Date.now().toString(), // Simple ID generation
    employee_id: (selectedEmployee.value as any).id,
    shift_id: (selectedShift.value as any).id,
    job_function: jobFunction
  })
}

const removeAssignment = (assignmentId: string) => {
  if (!scheduleAssignments.value) return
  const index = scheduleAssignments.value.findIndex((a: any) => a.id === assignmentId)
  if (index > -1) {
    scheduleAssignments.value.splice(index, 1)
  }
}

const assignEmployee = (employeeId: string) => {
  if (!scheduleAssignments.value || !selectedShift.value) return
  
  scheduleAssignments.value.push({
    id: Date.now().toString(),
    employee_id: employeeId,
    shift_id: (selectedShift.value as any).id,
    job_function: selectedJobFunction.value
  })
}

const removeEmployee = (employeeId: string) => {
  if (!scheduleAssignments.value || !selectedShift.value) return
  
  const index = scheduleAssignments.value.findIndex((a: any) => 
    a.employee_id === employeeId && 
    a.shift_id === (selectedShift.value as any).id &&
    a.job_function === selectedJobFunction.value
  )
  if (index > -1) {
    scheduleAssignments.value.splice(index, 1)
  }
}

const closeEmployeeModal = () => {
  showEmployeeModal.value = false
  selectedEmployee.value = null
  selectedShift.value = null
  selectedJobFunction.value = ''
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

const clearAssignmentsForDate = async (date: string) => {
  try {
    const { error } = await $supabase
      .from('schedule_assignments')
      .delete()
      .eq('schedule_date', date)

    if (error) throw error
  } catch (error) {
    console.error('Error clearing assignments:', error)
    throw error
  }
}

const saveSchedule = async () => {
  try {
    isSaving.value = true
    saveProgress.value = 'Preparing to save schedule...'
    
    // Clear existing assignments for this date first
    saveProgress.value = 'Clearing existing assignments...'
    await clearAssignmentsForDate(scheduleDate.value)
    
    // Convert scheduleAssignmentsData into contiguous ranges and save (batch-save improvement)
    saveProgress.value = 'Processing schedule data (merging ranges)...'
    const assignmentsToSave: any[] = []

    // Build a unified ordered list of 15-minute time slots across all active shifts
    const allSlots: string[] = (() => {
      if (!shifts.value || shifts.value.length === 0) return []
      const minStart = shifts.value
        .map((s: any) => timeToMinutes(s.start_time.substring(0, 5)))
        .reduce((a: number, b: number) => Math.min(a, b))
      const maxEnd = shifts.value
        .map((s: any) => timeToMinutes(s.end_time.substring(0, 5)))
        .reduce((a: number, b: number) => Math.max(a, b))
      const slots: string[] = []
      for (let m = minStart; m < maxEnd; m += 15) {
        slots.push(minutesToTime(m))
      }
      return slots
    })()

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
    
    // Save all assignments
    if (assignmentsToSave.length > 0) {
      saveProgress.value = `Saving ${assignmentsToSave.length} assignments to database...`
      // Faster: insert in batches of 200 for large schedules
      const batchSize = 200
      for (let i = 0; i < assignmentsToSave.length; i += batchSize) {
        const batch = assignmentsToSave.slice(i, i + batchSize)
        saveProgress.value = `Saving assignments ${i + 1}-${Math.min(i + batchSize, assignmentsToSave.length)} of ${assignmentsToSave.length}...`
        // useSchedule.createAssignment currently inserts a single row.
        // Use Supabase client directly for bulk insert to avoid N calls.
        const { error: insertError } = await $supabase
          .from('schedule_assignments')
          .insert(batch)
        if (insertError) throw insertError
      }
    }
    
    // Refresh the schedule data
    saveProgress.value = 'Refreshing schedule data...'
    await fetchScheduleForDate(scheduleDate.value)
    
    // Success!
    isSaving.value = false
    saveProgress.value = ''
    showNotification(`Schedule saved successfully! ${assignmentsToSave.length} assignments created.`, 'success')
    
  } catch (error: any) {
    console.error('Error saving schedule:', error)
    isSaving.value = false
    saveProgress.value = ''
    showNotification(`Error saving schedule: ${error.message || 'Unknown error'}. Please try again.`, 'error')
  }
}

// Event handlers for 15-minute grid
const handleAddAssignment = (employeeId: string, timeSlot: string) => {
  selectedEmployee.value = employees.value.find((e: any) => e.id === employeeId) || null
  selectedShift.value = { id: timeSlot, name: `${timeSlot} Slot` }
  showEmployeeModal.value = true
}

const handleEditAssignment = (employeeId: string, timeSlot: string) => {
  const assignment = getEmployeeAssignment(employeeId, timeSlot)
  if (assignment) {
    selectedEmployee.value = employees.value.find((e: any) => e.id === employeeId) || null
    selectedShift.value = { id: timeSlot, name: `${timeSlot} Slot` }
    selectedJobFunction.value = (assignment as any).job_function
    showEmployeeModal.value = true
  }
}

const handleBreakCoverage = (employeeId: string, timeSlot: any) => {
  // Handle break coverage assignment
  console.log('Assigning break coverage:', employeeId, timeSlot)
  // You can implement break coverage logic here
}

const handleScheduleDataUpdated = (newScheduleData: Record<string, any>) => {
  scheduleAssignmentsData.value = newScheduleData
  // Sync meter bookings when schedule data is updated
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
const existingPTORecord = ref<any>(null)
const ptoForm = ref({
  employee_id: '',
  pto_date: '',
  full_day: true,
  start_time: '08:00',
  end_time: '17:00'
})

const openPTOModal = (employee: any) => {
  ptoForm.value.employee_id = employee?.id || ''
  ptoForm.value.pto_date = scheduleDate.value
  const existingRecord = ptoByEmployeeId.value?.[employee?.id || '']?.find(
    (record: any) => record.pto_date === scheduleDate.value
  ) || null
  existingPTORecord.value = existingRecord

  if (existingRecord) {
    const isFullDay = !existingRecord.start_time && !existingRecord.end_time
    ptoForm.value.full_day = isFullDay
    ptoForm.value.start_time = existingRecord.start_time
      ? existingRecord.start_time.substring(0, 5)
      : '08:00'
    ptoForm.value.end_time = existingRecord.end_time
      ? existingRecord.end_time.substring(0, 5)
      : '17:00'
  } else {
    ptoForm.value.full_day = true
    ptoForm.value.start_time = '08:00'
    ptoForm.value.end_time = '17:00'
  }
  showPTOModal.value = true
}

const savePTO = async () => {
  if (!ptoForm.value.employee_id || !ptoForm.value.pto_date) return
  if (!ptoForm.value.full_day && (!ptoForm.value.start_time || !ptoForm.value.end_time)) {
    showNotification('Please provide start and end times for partial-day PTO.', 'error')
    return
  }
  if (existingPTORecord.value?.id) {
    const removed = await deletePTO(existingPTORecord.value.id)
    if (!removed) {
      showNotification('Failed to update PTO. Please try again.', 'error')
      return
    }
  }
  const record: any = {
    employee_id: ptoForm.value.employee_id,
    pto_date: ptoForm.value.pto_date
  }
  if (!ptoForm.value.full_day) {
    record.start_time = ptoForm.value.start_time + ':00'
    record.end_time = ptoForm.value.end_time + ':00'
  } else {
    record.start_time = null
    record.end_time = null
  }
  const ok = await createPTO(record)
  if (ok) {
    await fetchPTOForDate(scheduleDate.value)
    existingPTORecord.value = null
    showPTOModal.value = false
    showNotification('PTO saved successfully.', 'success')
  } else {
    showNotification('Failed to create PTO. Please try again.', 'error')
  }
}

const closePTOModal = () => {
  showPTOModal.value = false
  existingPTORecord.value = null
}

const deleteCurrentPTO = async () => {
  if (!existingPTORecord.value?.id) return
  const ok = await deletePTO(existingPTORecord.value.id)
  if (ok) {
    await fetchPTOForDate(scheduleDate.value)
    existingPTORecord.value = null
    showPTOModal.value = false
    showNotification('PTO removed.', 'success')
  } else {
    showNotification('Failed to remove PTO. Please try again.', 'error')
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

const saveShiftSwap = async () => {
  if (!shiftSwapForm.value.employee_id || !shiftSwapForm.value.swap_date || !shiftSwapForm.value.swapped_shift_id) return
  
  try {
    await createShiftSwap({
      employee_id: shiftSwapForm.value.employee_id,
      swap_date: shiftSwapForm.value.swap_date,
      original_shift_id: shiftSwapForm.value.original_shift_id,
      swapped_shift_id: shiftSwapForm.value.swapped_shift_id,
      notes: shiftSwapForm.value.notes || null
    })
    await fetchShiftSwapsForDate(scheduleDate.value)
    showShiftSwapModal.value = false
  } catch (e: any) {
    showNotification('Failed to save shift swap. Please try again.', 'error')
    console.error('Error saving shift swap:', e)
  }
}

const deleteShiftSwap = async () => {
  if (!existingShiftSwap.value?.id) return
  
  try {
    const ok = await deleteShiftSwapAction(existingShiftSwap.value.id)
    if (ok) {
      await fetchShiftSwapsForDate(scheduleDate.value)
      showShiftSwapModal.value = false
    } else {
      showNotification('Failed to delete shift swap. Please try again.', 'error')
    }
  } catch (e: any) {
    showNotification('Failed to delete shift swap. Please try again.', 'error')
    console.error('Error deleting shift swap:', e)
  }
}

const closeShiftSwapModal = () => {
  showShiftSwapModal.value = false
}

const getShiftName = (shiftId: string) => {
  const shift = scheduleData.value.find((s: any) => s.id === shiftId)
  return shift?.name || 'Unknown Shift'
}

// Meter dashboard functions
const meterTimeSlots = computed(() => {
  const slots = []
  // Generate time slots from 8 AM to 8 PM (08:00 to 20:00) to conserve space
  for (let hour = 8; hour <= 20; hour++) {
    for (let quarter = 0; quarter < 4; quarter++) {
      const minutes = quarter * 15
      const timeString = `${hour.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`
      
      // Stop at 8:00 PM (20:00) - only show up to 8pm, not 8:30pm
      if (hour === 20 && minutes > 0) break
      
      slots.push({
        time: timeString,
        hour,
        minutes
      })
    }
  }
  return slots
})

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

// Helper function to get dashboard label
const getDashboardLabel = (dashboard: string): string => {
  const labels: Record<string, string> = {
    'locus': 'Locus',
    'pick': 'Pick',
    'x4': 'X4',
    'em9': 'EM9',
    'speedcell': 'Speedcell',
    'helpdesk': 'Helpdesk',
    'rtPick': 'RT Pick',
    'projects': 'Projects',
    'dgPick': 'DG Pick'
  }
  return labels[dashboard] || dashboard
}

// Helper function to normalize job function names for matching
const normalizeJobFunctionName = (name: string): string => {
  // Convert dashboard key to job function name format
  const mapping: Record<string, string> = {
    'locus': 'Locus',
    'pick': 'Pick',
    'x4': 'X4',
    'em9': 'EM9',
    'speedcell': 'Speedcell',
    'helpdesk': 'Helpdesk',
    'rtpick': 'RT Pick',
    'projects': 'Projects',
    'dgpick': 'DG Pick'
  }
  return mapping[name.toLowerCase()] || name
}

// Get employees assigned to a specific job function
const getEmployeesForJobFunction = (jobFunctionKey: string) => {
  if (!employees.value || !scheduleAssignmentsData.value) return []
  
  const jobFunctionName = normalizeJobFunctionName(jobFunctionKey)
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

// Check if employee is assigned to job function at a specific time slot
const isEmployeeAssignedToJobFunction = (employeeId: string, timeSlot: string, jobFunctionKey: string): boolean => {
  if (!scheduleAssignmentsData.value || !scheduleAssignmentsData.value[employeeId]) return false
  
  const employeeSchedule = scheduleAssignmentsData.value[employeeId]
  const assignment = employeeSchedule[timeSlot]
  
  if (!assignment || !assignment.assignment) return false
  
  const jobFunctionName = normalizeJobFunctionName(jobFunctionKey)
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
  const jobFunctionName = normalizeJobFunctionName(jobFunctionKey)
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
  console.log('🔄 Syncing meter bookings...')
  console.log('Schedule assignments data:', scheduleAssignmentsData.value)
  
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
          
          if (meterNumber >= 1 && meterNumber <= 20) {
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
        console.log(`📊 Processing meter assignment: Meter ${range.meterNumber} at ${range.startTime} until ${range.endTime}`)
        
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
  
  console.log('📋 Final meter bookings:', meterBookings.value)
}


const { logout } = useAuth()

const handleLogout = async () => {
  if (confirm('Are you sure you want to logout?')) {
    await logout()
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

// Prevent accidental navigation during save
onMounted(() => {
  window.addEventListener('beforeunload', (e) => {
    if (isSaving.value) {
      e.preventDefault()
      e.returnValue = 'Schedule is currently saving. Are you sure you want to leave?'
    }
  })
})

onUnmounted(() => {
  window.removeEventListener('beforeunload', (e) => {
    if (isSaving.value) {
      e.preventDefault()
      e.returnValue = 'Schedule is currently saving. Are you sure you want to leave?'
    }
  })
})

</script>

<style scoped>
</style>