<template>
  <div class="fixed inset-0 bg-black/50 flex items-start justify-center z-50 p-4 overflow-y-auto" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-2xl max-w-6xl w-full my-4">
      <div class="p-6">

        <!-- Header -->
        <div class="flex justify-between items-start mb-4">
          <div>
            <h2 class="text-xl font-bold text-gray-900">Employee Overview</h2>
            <p class="text-sm text-gray-500 mt-0.5">
              Scheduled work, skills and attendance drawn from schedule history.
            </p>
          </div>
          <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600 text-2xl leading-none">&times;</button>
        </div>

        <!-- Filter row: scopes every panel below -->
        <div class="flex flex-wrap items-end gap-3 p-3 bg-gray-50 border border-gray-200 rounded-lg mb-4">
          <div class="flex-1 min-w-[220px]">
            <label class="block text-xs font-medium text-gray-500 mb-1">Employee</label>
            <select
              v-model="employeeId"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900 text-sm"
            >
              <option value="">Select employee...</option>
              <option v-for="emp in employees" :key="emp.id" :value="emp.id">
                {{ emp.last_name }}, {{ emp.first_name }}
              </option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-500 mb-1">Period</label>
            <div class="inline-flex rounded-md border border-gray-300 overflow-hidden">
              <button
                v-for="p in periods"
                :key="p.key"
                type="button"
                @click="period = p.key"
                class="px-3 py-2 text-xs font-medium border-r border-gray-200 last:border-r-0"
                :class="period === p.key ? 'bg-blue-50 text-blue-700' : 'bg-white text-gray-600 hover:bg-gray-50'"
              >{{ p.label }}</button>
            </div>
          </div>
          <button
            @click="exportCsv"
            :disabled="!data"
            class="ml-auto px-3 py-2 text-sm rounded-md bg-green-600 text-white hover:bg-green-700 disabled:opacity-40"
          >
            Export CSV
          </button>
        </div>

        <!-- Empty / loading -->
        <div v-if="!employeeId" class="text-sm text-gray-500 py-16 text-center">
          Select an employee to see their overview.
        </div>
        <div v-else-if="loading && !data" class="text-sm text-gray-500 py-16 text-center">Loading…</div>
        <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-md p-3 text-sm text-red-700">
          {{ error }}
        </div>

        <!-- Dashboard. Held at reduced opacity while refetching so there's no skeleton flash. -->
        <div v-else-if="data" :class="loading ? 'opacity-60 transition-opacity' : ''">

          <!-- Summary tiles -->
          <div class="grid grid-cols-2 md:grid-cols-5 gap-2.5 mb-3">
            <div class="border border-gray-200 rounded-lg p-3">
              <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium">Days scheduled</div>
              <div class="text-2xl font-bold text-gray-900 leading-tight">{{ data.summary.daysScheduled }}</div>
              <div class="text-[11px] text-gray-500">
                {{ data.summary.firstDate ? shortDate(data.summary.firstDate) + ' – ' + shortDate(data.summary.lastDate) : 'No schedule data' }}
              </div>
            </div>
            <div class="border border-gray-200 rounded-lg p-3">
              <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium">Hours scheduled</div>
              <div class="text-2xl font-bold text-gray-900 leading-tight">{{ data.summary.hoursScheduled }}<span class="text-sm font-medium text-gray-500 ml-0.5">h</span></div>
              <div class="text-[11px] text-gray-500">{{ data.summary.avgHoursPerDay }}h avg / day</div>
            </div>
            <div class="border border-gray-200 rounded-lg p-3">
              <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium">Time off taken</div>
              <div class="text-2xl font-bold text-gray-900 leading-tight">{{ data.summary.absenceHours }}<span class="text-sm font-medium text-gray-500 ml-0.5">h</span></div>
              <div class="text-[11px] text-gray-500">{{ absenceCount }} occurrence{{ absenceCount === 1 ? '' : 's' }}</div>
            </div>
            <div class="border border-gray-200 rounded-lg p-3">
              <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium">Call-ins</div>
              <div class="text-2xl font-bold leading-tight" :class="data.summary.callIns > 0 ? 'text-amber-600' : 'text-gray-900'">{{ data.summary.callIns }}</div>
              <div class="text-[11px] text-gray-500">unplanned absences</div>
            </div>
            <div class="border border-gray-200 rounded-lg p-3">
              <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium">Functions worked</div>
              <div class="text-2xl font-bold text-gray-900 leading-tight">{{ data.summary.functionsWorked }}</div>
              <div class="text-[11px] text-gray-500">of {{ data.summary.functionsTrained }} trained</div>
            </div>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-12 gap-3 mb-3">

            <!-- WORK MIX -->
            <div class="lg:col-span-7 border border-gray-200 rounded-lg p-4">
              <div class="flex justify-between items-baseline mb-3">
                <h3 class="font-semibold text-gray-900 text-sm">Work mix</h3>
                <button
                  @click="showMixTable = !showMixTable"
                  class="text-xs text-blue-600 hover:text-blue-800"
                >{{ showMixTable ? 'Chart view' : 'Table view' }}</button>
              </div>

              <div v-if="!data.workMix.length" class="text-sm text-gray-500 py-6 text-center">
                No scheduled assignments in this period.
              </div>

              <!-- Bars: one series, one colour. The function's own colour rides as a
                   chip so it stays recognisable against the schedule grid. -->
              <div v-else-if="!showMixTable" class="space-y-0.5">
                <div
                  v-for="m in data.workMix"
                  :key="m.id"
                  class="grid grid-cols-[110px_1fr_96px] items-center gap-3 py-1 px-1.5 rounded hover:bg-gray-50"
                  :title="`${m.name} — ${m.hours}h over ${m.days} day${m.days === 1 ? '' : 's'}`"
                >
                  <div class="flex items-center gap-2 min-w-0">
                    <span class="w-2.5 h-2.5 rounded-sm flex-none" :style="{ backgroundColor: m.color }"></span>
                    <span class="text-[13px] text-gray-800 truncate">{{ m.name }}</span>
                  </div>
                  <div class="h-2.5 bg-gray-100 rounded-sm overflow-hidden">
                    <div class="h-full bg-blue-600 rounded-r-sm" :style="{ width: barWidth(m.hours) }"></div>
                  </div>
                  <div class="text-xs text-right tabular-nums text-gray-900">
                    {{ m.hours }}h <span class="text-gray-400">{{ m.share }}%</span>
                  </div>
                </div>
              </div>

              <div v-else class="overflow-x-auto">
                <table class="min-w-full text-xs">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-2 py-1.5 text-left font-medium text-gray-500">Function</th>
                      <th class="px-2 py-1.5 text-right font-medium text-gray-500">Hours</th>
                      <th class="px-2 py-1.5 text-right font-medium text-gray-500">Days</th>
                      <th class="px-2 py-1.5 text-right font-medium text-gray-500">Share</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    <tr v-for="m in data.workMix" :key="m.id">
                      <td class="px-2 py-1.5 text-gray-800">{{ m.name }}</td>
                      <td class="px-2 py-1.5 text-right tabular-nums">{{ m.hours }}</td>
                      <td class="px-2 py-1.5 text-right tabular-nums">{{ m.days }}</td>
                      <td class="px-2 py-1.5 text-right tabular-nums">{{ m.share }}%</td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <div v-if="data.workMix.length" class="mt-3 pt-3 border-t border-gray-100 text-xs text-gray-600 space-y-1">
                <div>
                  <b class="text-gray-900">{{ data.summary.blocksPerDay }}</b> assignment blocks per day ·
                  <b class="text-gray-900">{{ data.summary.avgBlockHours }}h</b> average block length
                </div>
                <div v-if="data.skills.teamAvgWorked !== null">
                  Team average is {{ data.skills.teamAvgWorked }} functions per person.
                  <span v-if="data.summary.functionsWorked > data.skills.teamAvgWorked">Above average.</span>
                  <span v-else-if="data.summary.functionsWorked < data.skills.teamAvgWorked">Below average.</span>
                  <span v-else>In line.</span>
                </div>
              </div>
            </div>

            <!-- SKILLS -->
            <div class="lg:col-span-5 border border-gray-200 rounded-lg p-4">
              <div class="flex justify-between items-baseline mb-3">
                <h3 class="font-semibold text-gray-900 text-sm">Skills &amp; training</h3>
                <span class="text-[10px] uppercase tracking-wide text-gray-400">{{ data.skills.trained.length }} certified</span>
              </div>

              <div v-if="!data.skills.trained.length" class="text-sm text-gray-500 py-6 text-center">
                No training records for this employee.
              </div>

              <template v-else>
                <div class="mb-1.5 flex justify-between items-baseline text-[13px]">
                  <span class="text-gray-700">Training in use</span>
                  <span class="text-xs text-gray-500 tabular-nums">{{ usedTrainingCount }} of {{ data.skills.trained.length }}</span>
                </div>
                <div class="flex gap-0.5 h-2.5 bg-gray-100 rounded-sm overflow-hidden mb-4">
                  <span class="bg-blue-600 h-full" :style="{ width: usedPct + '%' }"></span>
                  <span class="bg-amber-400 h-full" :style="{ width: (100 - usedPct) + '%' }"></span>
                </div>

                <div v-if="data.skills.neverWorked.length" class="mb-3">
                  <div class="text-xs text-gray-600 mb-1.5">
                    Trained but never scheduled
                    <span class="ml-1 px-1.5 py-0.5 rounded bg-amber-100 text-amber-800 font-medium">{{ data.skills.neverWorked.length }} unused</span>
                  </div>
                  <div class="flex flex-wrap gap-1">
                    <span
                      v-for="t in data.skills.neverWorked"
                      :key="t.id"
                      class="text-[11px] border border-amber-300 bg-amber-50 text-amber-900 rounded px-1.5 py-0.5"
                    >{{ t.name }}</span>
                  </div>
                </div>

                <div v-if="data.skills.stale.length" class="mb-3">
                  <div class="text-xs text-gray-600 mb-1.5">
                    Not worked in {{ data.skills.staleDays }}+ days
                    <span class="ml-1 px-1.5 py-0.5 rounded bg-gray-100 text-gray-700 font-medium">{{ data.skills.stale.length }}</span>
                  </div>
                  <div class="flex flex-wrap gap-1">
                    <span
                      v-for="t in data.skills.stale"
                      :key="t.id"
                      class="text-[11px] border border-gray-300 text-gray-600 rounded px-1.5 py-0.5"
                      :title="'Last worked ' + shortDate(t.lastWorked)"
                    >{{ t.name }}</span>
                  </div>
                </div>

                <div
                  v-if="data.skills.teamAvgTrained !== null"
                  class="mt-3 pt-3 border-t border-gray-100 text-xs text-gray-600"
                >
                  Team-wide, staff average <b class="text-gray-900">{{ data.skills.teamAvgTrained }}</b> trainings
                  and work <b class="text-gray-900">{{ data.skills.teamAvgWorked }}</b>.
                </div>
              </template>
            </div>
          </div>

          <!-- ATTENDANCE -->
          <div class="border border-gray-200 rounded-lg p-4 mb-3">
            <h3 class="font-semibold text-gray-900 text-sm mb-3">Attendance &amp; requests</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">

              <div>
                <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium mb-2">Time off taken</div>
                <div v-if="!absenceCount" class="text-sm text-gray-400 py-3">None in this period.</div>
                <template v-else>
                  <div
                    v-for="(v, k) in data.attendance.byKind"
                    :key="k"
                    class="flex justify-between items-baseline py-1 border-b border-gray-100 text-[13px]"
                  >
                    <span class="text-gray-700">{{ kindLabel(String(k)) }}</span>
                    <span class="tabular-nums text-gray-900">{{ v.count }} · {{ v.hours }}h</span>
                  </div>
                  <div class="flex justify-between items-baseline py-1 text-[13px] font-semibold">
                    <span>Total</span>
                    <span class="tabular-nums">{{ data.attendance.totalHours }}h</span>
                  </div>
                </template>
              </div>

              <div>
                <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium mb-2">Requests</div>
                <div class="flex justify-between items-baseline py-1 border-b border-gray-100 text-[13px]">
                  <span class="text-gray-700">Submitted</span><span class="tabular-nums">{{ data.attendance.requestsSubmitted }}</span>
                </div>
                <div class="flex justify-between items-baseline py-1 border-b border-gray-100 text-[13px]">
                  <span class="text-gray-700">Approved</span><span class="tabular-nums text-green-700">{{ data.attendance.requestsApproved }}</span>
                </div>
                <div class="flex justify-between items-baseline py-1 border-b border-gray-100 text-[13px]">
                  <span class="text-gray-700">Rejected</span><span class="tabular-nums" :class="data.attendance.requestsRejected ? 'text-red-700' : ''">{{ data.attendance.requestsRejected }}</span>
                </div>
                <div class="flex justify-between items-baseline py-1 border-b border-gray-100 text-[13px]">
                  <span class="text-gray-700">Shift changes</span><span class="tabular-nums">{{ data.attendance.shiftChanges }}</span>
                </div>
                <div class="flex justify-between items-baseline py-1 text-[13px]">
                  <span class="text-gray-700">Avg notice given</span>
                  <span class="tabular-nums">{{ data.attendance.avgNoticeBusinessDays !== null ? data.attendance.avgNoticeBusinessDays + ' days' : '—' }}</span>
                </div>
              </div>

              <div>
                <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium mb-2">Absences by weekday</div>
                <div v-if="!absenceCount" class="text-sm text-gray-400 py-3">None in this period.</div>
                <template v-else>
                  <div class="flex items-end gap-1.5 h-24">
                    <div v-for="d in weekdayBars" :key="d.label" class="flex-1 flex flex-col items-center justify-end gap-1 h-full">
                      <span class="text-[11px] tabular-nums" :class="d.peak ? 'text-gray-900 font-semibold' : 'text-gray-500'">{{ d.n }}</span>
                      <div
                        class="w-full bg-blue-600 rounded-t-sm"
                        :class="d.peak ? '' : 'opacity-35'"
                        :style="{ height: d.h }"
                      ></div>
                      <span class="text-[10px] text-gray-500">{{ d.label }}</span>
                    </div>
                  </div>
                  <div v-if="mondayFridayShare >= 60" class="mt-2 text-xs text-gray-600">
                    <span class="px-1.5 py-0.5 rounded bg-amber-100 text-amber-800 font-medium">Pattern</span>
                    {{ mondayFridayShare }}% of absences fall on Mon or Fri.
                  </div>
                </template>
              </div>
            </div>
          </div>

          <!-- PERFORMANCE: errors + notes. Admin-only; the API returns null for
               everyone else, so this whole block simply isn't rendered. -->
          <template v-if="data.canSeePerformance && data.performance">

            <!-- ERRORS — full width -->
            <div class="border border-gray-200 rounded-lg p-4 mb-3">
              <div class="flex justify-between items-baseline mb-1">
                <h3 class="font-semibold text-gray-900 text-sm">Errors logged</h3>
                <button @click="showErrorForm = !showErrorForm" class="text-xs text-blue-600 hover:text-blue-800">
                  {{ showErrorForm ? 'Cancel' : '+ Log an error' }}
                </button>
              </div>
              <p class="text-xs text-gray-500 mb-3">
                Rolling {{ data.performance.windowDays }}-day count, sampled weekly. Counts, not a rate —
                someone working more hours will naturally show more.
              </p>

              <!-- Add form -->
              <form v-if="showErrorForm" @submit.prevent="submitError" class="bg-gray-50 border border-gray-200 rounded-md p-3 mb-3 space-y-2">
                <div class="grid grid-cols-2 gap-2">
                  <div>
                    <label class="block text-[11px] font-medium text-gray-600 mb-1">Date</label>
                    <input v-model="errorForm.error_date" type="date" required
                      class="w-full px-2 py-1.5 text-sm border border-gray-300 rounded bg-white" />
                  </div>
                  <div>
                    <label class="block text-[11px] font-medium text-gray-600 mb-1">Function</label>
                    <select v-model="errorForm.job_function_id"
                      class="w-full px-2 py-1.5 text-sm border border-gray-300 rounded bg-white">
                      <option value="">Unspecified</option>
                      <option v-for="f in jobFunctions" :key="f.id" :value="f.id">{{ f.name }}</option>
                    </select>
                  </div>
                </div>
                <div class="grid grid-cols-2 gap-2">
                  <div>
                    <label class="block text-[11px] font-medium text-gray-600 mb-1">How many</label>
                    <input v-model.number="errorForm.error_count" type="number" min="1" required
                      class="w-full px-2 py-1.5 text-sm border border-gray-300 rounded bg-white" />
                  </div>
                  <div>
                    <label class="block text-[11px] font-medium text-gray-600 mb-1">Type (optional)</label>
                    <input v-model="errorForm.error_type" list="error-types" placeholder="e.g. wrong quantity"
                      class="w-full px-2 py-1.5 text-sm border border-gray-300 rounded bg-white" />
                    <datalist id="error-types">
                      <option v-for="t in ERROR_TYPES" :key="t" :value="t"></option>
                    </datalist>
                  </div>
                </div>
                <div>
                  <label class="block text-[11px] font-medium text-gray-600 mb-1">Notes (optional)</label>
                  <input v-model="errorForm.notes" placeholder="Order number, what happened…"
                    class="w-full px-2 py-1.5 text-sm border border-gray-300 rounded bg-white" />
                </div>
                <div v-if="errorFormError" class="text-xs text-red-600">{{ errorFormError }}</div>
                <button type="submit" :disabled="savingError"
                  class="w-full px-3 py-1.5 text-sm bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50">
                  {{ savingError ? 'Saving…' : 'Log error' }}
                </button>
              </form>

              <div v-if="!data.performance.totalErrors" class="text-sm text-gray-500 py-6 text-center">
                No errors logged in this period.
              </div>

              <template v-else>
                <div class="flex flex-wrap items-baseline gap-x-6 gap-y-2 mb-3">
                  <div>
                    <div class="text-2xl font-bold text-gray-900 leading-none">{{ data.performance.totalErrors }}</div>
                    <div class="text-[11px] text-gray-500 mt-0.5">errors in this period</div>
                  </div>
                  <div class="text-xs text-gray-600">
                    across {{ data.performance.errorEntries }} entr{{ data.performance.errorEntries === 1 ? 'y' : 'ies' }}
                    <span v-if="data.performance.byFunction.length">
                      · mostly {{ data.performance.byFunction[0].name }} ({{ data.performance.byFunction[0].count }})
                    </span>
                    <span v-if="data.performance.peak30">
                      · peaked at <b class="text-gray-900">{{ data.performance.peak30 }}</b> in a 30-day window
                    </span>
                  </div>
                </div>

                <!-- Rolling 30-day trend. Single series, one colour, so no legend.
                     Endpoint is labelled so the current figure reads without hovering. -->
                <div class="relative" @mouseleave="hoverPoint = null">
                  <svg :viewBox="`0 0 ${CHART.w} ${CHART.h}`" preserveAspectRatio="none"
                       class="w-full block" style="height:180px; overflow:visible">
                    <!-- gridlines + y ticks -->
                    <g>
                      <template v-for="t in chartTicks" :key="t.v">
                        <line :x1="CHART.padL" :y1="t.y" :x2="CHART.w - CHART.padR" :y2="t.y"
                              stroke="#f3f4f6" stroke-width="1" />
                        <text :x="CHART.padL - 8" :y="t.y + 3.5" text-anchor="end"
                              font-size="10" fill="#9ca3af" font-family="system-ui">{{ t.v }}</text>
                      </template>
                    </g>
                    <!-- x labels -->
                    <text v-for="l in chartXLabels" :key="l.x" :x="l.x" :y="CHART.h - 8"
                          text-anchor="middle" font-size="10" fill="#9ca3af" font-family="system-ui">{{ l.label }}</text>

                    <defs>
                      <linearGradient id="errFill" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stop-color="#2563eb" stop-opacity="0.22" />
                        <stop offset="100%" stop-color="#2563eb" stop-opacity="0" />
                      </linearGradient>
                    </defs>
                    <path :d="chartArea" fill="url(#errFill)" />
                    <path :d="chartLine" fill="none" stroke="#2563eb" stroke-width="2" stroke-linejoin="round" />

                    <!-- crosshair -->
                    <line v-if="hoverPoint" :x1="hoverPoint.x" :y1="CHART.padT" :x2="hoverPoint.x" :y2="CHART.h - CHART.padB"
                          stroke="#9ca3af" stroke-width="1" />
                    <circle v-if="hoverPoint" :cx="hoverPoint.x" :cy="hoverPoint.y" r="4"
                            fill="#2563eb" stroke="#fff" stroke-width="2" />

                    <!-- endpoint marker + direct label -->
                    <circle v-if="chartPoints.length" :cx="chartPoints[chartPoints.length - 1].x"
                            :cy="chartPoints[chartPoints.length - 1].y" r="3.5"
                            fill="#2563eb" stroke="#fff" stroke-width="2" />
                    <text v-if="chartPoints.length" :x="chartPoints[chartPoints.length - 1].x - 6"
                          :y="chartPoints[chartPoints.length - 1].y - 9" text-anchor="end"
                          font-size="11" font-weight="600" fill="#2563eb" font-family="system-ui">
                      {{ data.performance.current30 }} in last {{ data.performance.windowDays }}d
                    </text>

                    <!-- hit columns: a wide target rather than a pinpoint on the line -->
                    <rect v-for="(p, i) in chartPoints" :key="'hit' + i"
                          :x="p.x - chartHitWidth / 2" :y="CHART.padT"
                          :width="chartHitWidth" :height="CHART.h - CHART.padT - CHART.padB"
                          fill="transparent" @mouseenter="hoverPoint = p" />
                  </svg>
                  <div v-if="hoverPoint"
                       class="absolute pointer-events-none bg-gray-900 text-white text-[11px] rounded px-2 py-1 whitespace-nowrap"
                       :style="{ left: `calc(${(hoverPoint.x / CHART.w) * 100}% - 60px)`, top: '-4px' }">
                    {{ longDate(hoverPoint.date) }} — {{ hoverPoint.count }} in prior {{ data.performance.windowDays }} days
                  </div>
                </div>

                <!-- Recent entries: every value stays readable without the chart -->
                <div class="mt-3 pt-3 border-t border-gray-100 max-h-40 overflow-y-auto">
                  <div
                    v-for="e in data.performance.errors.slice(0, 12)"
                    :key="e.id"
                    class="flex items-start justify-between gap-2 py-1 text-xs border-b border-gray-50 last:border-b-0"
                  >
                    <div class="min-w-0">
                      <span class="tabular-nums text-gray-700">{{ shortDate(e.error_date) }}</span>
                      <span class="text-gray-900 ml-2">{{ e.job_function_name || 'Unspecified' }}</span>
                      <span v-if="e.error_count > 1" class="ml-1 text-gray-500">×{{ e.error_count }}</span>
                      <span v-if="e.error_type" class="ml-2 text-gray-500">{{ e.error_type }}</span>
                      <div v-if="e.notes" class="text-gray-400 truncate">{{ e.notes }}</div>
                    </div>
                    <button @click="deleteError(e)" class="text-gray-400 hover:text-red-600 flex-none" title="Delete">&times;</button>
                  </div>
                </div>
              </template>
            </div>

            <!-- NOTES — full width -->
            <div class="border border-gray-200 rounded-lg p-4 mb-3">
              <div class="flex justify-between items-baseline mb-1">
                <h3 class="font-semibold text-gray-900 text-sm">Performance notes</h3>
                <button @click="showNoteForm = !showNoteForm" class="text-xs text-blue-600 hover:text-blue-800">
                  {{ showNoteForm ? 'Cancel' : '+ Write a note' }}
                </button>
              </div>
              <p class="text-xs text-gray-500 mb-3">Visible to admins only.</p>

              <!-- Quick add: one click logs it against today. -->
              <div class="bg-gray-50 border border-gray-200 rounded-md p-2.5 mb-3">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">Quick add · today</span>
                  <span v-if="quickToast" class="text-[11px] text-gray-600">
                    {{ quickToast.label }} logged ·
                    <button @click="undoQuick" class="text-blue-600 hover:text-blue-800 underline">Undo</button>
                  </span>
                </div>
                <!-- Grouped so praise and concerns don't read as one undifferentiated pile -->
                <div class="space-y-2">
                  <div v-for="grp in [{ k: 'positive', label: 'Positive', items: quickPositive },
                                      { k: 'concern', label: 'Needs attention', items: quickConcern }]" :key="grp.k">
                    <div class="text-[10px] uppercase tracking-wide text-gray-400 mb-1">{{ grp.label }}</div>
                    <div class="flex flex-wrap gap-1.5">
                      <button
                        v-for="q in grp.items"
                        :key="q.tag"
                        type="button"
                        :disabled="quickSaving === q.tag"
                        @click="quickAdd(q)"
                        class="px-2.5 py-1 text-xs rounded-full border transition disabled:opacity-50"
                        :class="quickButtonClass(q.category)"
                        :title="q.body"
                      >
                        {{ q.label }}
                        <span v-if="tagCount(q.tag)" class="ml-1 font-semibold tabular-nums">{{ tagCount(q.tag) }}</span>
                      </button>
                    </div>
                  </div>
                </div>
                <p v-if="quickError" class="text-[11px] text-red-600 mt-1.5">{{ quickError }}</p>
                <p v-else-if="data.performance.tagCounts.length" class="text-[11px] text-gray-500 mt-1.5">
                  Counts show how many times each has been logged in this period.
                </p>
              </div>

              <form v-if="showNoteForm" @submit.prevent="submitNote" class="bg-gray-50 border border-gray-200 rounded-md p-3 mb-3 space-y-2">
                <div class="grid grid-cols-2 gap-2">
                  <div>
                    <label class="block text-[11px] font-medium text-gray-600 mb-1">Date</label>
                    <input v-model="noteForm.note_date" type="date" required
                      class="w-full px-2 py-1.5 text-sm border border-gray-300 rounded bg-white" />
                  </div>
                  <div>
                    <label class="block text-[11px] font-medium text-gray-600 mb-1">Category</label>
                    <select v-model="noteForm.category"
                      class="w-full px-2 py-1.5 text-sm border border-gray-300 rounded bg-white">
                      <option value="positive">Positive</option>
                      <option value="coaching">Coaching</option>
                      <option value="concern">Concern</option>
                      <option value="general">General</option>
                    </select>
                  </div>
                </div>
                <div>
                  <label class="block text-[11px] font-medium text-gray-600 mb-1">Note</label>
                  <textarea v-model="noteForm.body" rows="3" required maxlength="5000"
                    placeholder="What happened, what was discussed…"
                    class="w-full px-2 py-1.5 text-sm border border-gray-300 rounded bg-white"></textarea>
                </div>
                <div v-if="noteFormError" class="text-xs text-red-600">{{ noteFormError }}</div>
                <button type="submit" :disabled="savingNote"
                  class="w-full px-3 py-1.5 text-sm bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50">
                  {{ savingNote ? 'Saving…' : 'Save note' }}
                </button>
              </form>

              <div v-if="!data.performance.notes.length" class="text-sm text-gray-500 py-6 text-center">
                No notes recorded in this period.
              </div>
              <!-- Full width lets several notes be read at once during a review. -->
              <div v-else class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-2.5">
                <div
                  v-for="n in data.performance.notes"
                  :key="n.id"
                  class="border border-gray-200 border-l-[3px] rounded-md p-2.5"
                  :class="noteRailClass(n.category)"
                >
                  <div class="flex items-center justify-between gap-2 mb-1">
                    <div class="flex items-center gap-2 min-w-0">
                      <span class="px-1.5 py-0.5 rounded text-[10px] font-medium" :class="noteCategoryClass(n.category)">
                        {{ n.category }}
                      </span>
                      <span class="text-[11px] text-gray-500 tabular-nums">{{ shortDate(n.note_date) }}</span>
                    </div>
                    <button @click="deleteNote(n)" class="text-gray-400 hover:text-red-600 flex-none text-sm" title="Delete">&times;</button>
                  </div>
                  <p class="text-[13px] text-gray-800 whitespace-pre-wrap break-words">{{ n.body }}</p>
                  <div class="text-[10px] text-gray-400 mt-1">
                    {{ n.author }}<span v-if="n.updated_at !== n.created_at"> · edited</span>
                  </div>
                </div>
              </div>
            </div>
          </template>

          <!-- ACTIVITY LOG -->
          <div class="border border-gray-200 rounded-lg p-4">
            <h3 class="font-semibold text-gray-900 text-sm mb-3">Activity log</h3>
            <div v-if="!data.activity.length" class="text-sm text-gray-500 py-4 text-center">
              No requests or call-ins in this period.
            </div>
            <div v-else class="overflow-x-auto">
              <table class="min-w-full text-sm">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-3 py-2 text-left font-medium text-gray-500">Date</th>
                    <th class="px-3 py-2 text-left font-medium text-gray-500">Type</th>
                    <th class="px-3 py-2 text-left font-medium text-gray-500">Time</th>
                    <th class="px-3 py-2 text-left font-medium text-gray-500">Status</th>
                    <th class="px-3 py-2 text-left font-medium text-gray-500">Notes / reason</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <tr v-for="row in data.activity" :key="row.id">
                    <td class="px-3 py-2 whitespace-nowrap">{{ longDate(row.date) }}</td>
                    <td class="px-3 py-2 whitespace-nowrap">{{ typeLabel(row.type) }}</td>
                    <td class="px-3 py-2 text-gray-500 whitespace-nowrap">{{ timeLabel(row) || '—' }}</td>
                    <td class="px-3 py-2">
                      <span class="px-2 py-0.5 rounded-full text-xs font-medium" :class="statusClass(row.status)">
                        {{ statusLabel(row.status) }}
                      </span>
                    </td>
                    <td class="px-3 py-2 text-gray-500 max-w-[280px] truncate" :title="row.notes || ''">{{ row.notes || '—' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Delete confirmation. Sits above the overview modal and names the exact
         record, so a mis-click can't quietly remove someone's history. -->
    <div
      v-if="pendingDelete"
      class="fixed inset-0 bg-black/60 flex items-center justify-center z-[60] p-4"
      @click.self="pendingDelete = null"
    >
      <div class="bg-white rounded-xl shadow-2xl max-w-sm w-full">
        <div class="p-5">
          <h3 class="text-base font-bold text-gray-900 mb-1">{{ pendingDelete.title }}</h3>
          <p class="text-sm text-gray-600 mb-3">{{ pendingDelete.message }}</p>

          <div class="bg-gray-50 border border-gray-200 rounded-md p-2.5 mb-4">
            <p class="text-[13px] text-gray-800 whitespace-pre-wrap break-words">{{ pendingDelete.detail }}</p>
            <p v-if="pendingDelete.sub" class="text-[11px] text-gray-500 mt-1">{{ pendingDelete.sub }}</p>
          </div>

          <div class="flex gap-2">
            <button
              type="button"
              @click="pendingDelete = null"
              class="flex-1 px-3 py-2 text-sm rounded-md bg-gray-100 text-gray-700 hover:bg-gray-200 font-medium"
            >
              Keep it
            </button>
            <button
              type="button"
              @click="confirmDelete"
              :disabled="deleting"
              class="flex-1 px-3 py-2 text-sm rounded-md bg-red-600 text-white hover:bg-red-700 disabled:opacity-50 font-medium"
            >
              {{ deleting ? 'Deleting…' : 'Delete' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{ preselectedEmployeeId?: string | null }>()
defineEmits<{ close: [] }>()

const { employees, fetchEmployees } = useEmployees()
const { jobFunctions, fetchJobFunctions } = useJobFunctions()

const employeeId = ref(props.preselectedEmployeeId || '')
const data = ref<any>(null)
const loading = ref(false)
const error = ref('')
const showMixTable = ref(false)

const periods = [
  { key: '7d', label: '7d' },
  { key: '30d', label: '30d' },
  { key: '90d', label: '90d' },
  { key: '12mo', label: '12mo' },
  { key: 'all', label: 'All' },
]
const period = ref('all')

const pad = (n: number) => String(n).padStart(2, '0')
const toStr = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`

// "All" spans future-dated schedules too, so an already-published upcoming day
// isn't missing from the picture. The bounded presets are honest lookbacks.
const range = computed(() => {
  const today = new Date()
  if (period.value === 'all') return { from: '2000-01-01', to: '2100-01-01' }
  const start = new Date(today)
  if (period.value === '7d') start.setDate(start.getDate() - 7)
  else if (period.value === '30d') start.setDate(start.getDate() - 30)
  else if (period.value === '90d') start.setDate(start.getDate() - 90)
  else start.setFullYear(start.getFullYear() - 1)
  return { from: toStr(start), to: toStr(today) }
})

const load = async () => {
  if (!employeeId.value) { data.value = null; return }
  loading.value = true
  error.value = ''
  try {
    data.value = await $fetch<any>(`/api/employees/${employeeId.value}/overview`, {
      params: { from: range.value.from, to: range.value.to },
    })
  } catch (e: any) {
    error.value = e.data?.message || e.message || 'Failed to load overview'
    data.value = null
  } finally {
    loading.value = false
  }
}

watch([employeeId, period], load)

const absenceCount = computed(() =>
  Object.values(data.value?.attendance?.byKind ?? {}).reduce((s: number, v: any) => s + v.count, 0)
)

const usedTrainingCount = computed(() => {
  const t = data.value?.skills?.trained ?? []
  return t.filter((x: any) => !x.neverWorked).length
})
const usedPct = computed(() => {
  const total = data.value?.skills?.trained?.length ?? 0
  return total ? Math.round((usedTrainingCount.value / total) * 100) : 0
})

const maxMixHours = computed(() =>
  Math.max(...(data.value?.workMix ?? []).map((m: any) => m.hours), 0)
)
const barWidth = (h: number) => (maxMixHours.value > 0 ? `${(h / maxMixHours.value) * 100}%` : '0%')

// Mon..Fri, reordered from the API's Sun-first array.
const weekdayBars = computed(() => {
  const w = data.value?.attendance?.byWeekday ?? []
  const days = [
    { label: 'Mon', n: w[1] ?? 0 }, { label: 'Tue', n: w[2] ?? 0 },
    { label: 'Wed', n: w[3] ?? 0 }, { label: 'Thu', n: w[4] ?? 0 },
    { label: 'Fri', n: w[5] ?? 0 },
  ]
  const max = Math.max(...days.map((d) => d.n), 1)
  return days.map((d) => ({
    ...d,
    peak: d.n === max && d.n > 0,
    h: d.n > 0 ? `${Math.max((d.n / max) * 100, 6)}%` : '3%',
  }))
})

const mondayFridayShare = computed(() => {
  const w = data.value?.attendance?.byWeekday ?? []
  const total = w.reduce((s: number, n: number) => s + n, 0)
  if (!total) return 0
  return Math.round((((w[1] ?? 0) + (w[5] ?? 0)) / total) * 100)
})

// --- labels -------------------------------------------------------------------
const KIND_LABELS: Record<string, string> = {
  full_day: 'Full days',
  partial: 'Partial days',
  leave_early: 'Leave early',
  arrive_late: 'Arrive late',
  call_in: 'Call-ins',
}
const kindLabel = (k: string) => KIND_LABELS[k] || k

const TYPE_LABELS: Record<string, string> = {
  leave_early: 'Leave Early',
  leave_on_time: 'Leave on Time',
  arrive_late: 'Arrive Late',
  pto_full_day: 'Full Day Off',
  pto_partial: 'Partial Day',
  shift_swap: 'Shift Change',
  call_in: 'Call-In',
  manual_full_day: 'Full Day Off (manual)',
  manual_partial: 'Partial Day (manual)',
  manual_leave_early: 'Leave Early (manual)',
  manual_arrive_late: 'Arrive Late (manual)',
}
const typeLabel = (t: string) => TYPE_LABELS[t] || t

const statusLabel = (s: string) => (s === 'logged' ? 'call-in' : s)
const statusClass = (s: string) => ({
  'bg-green-100 text-green-800': s === 'approved',
  'bg-yellow-100 text-yellow-800': s === 'pending',
  'bg-red-100 text-red-800': s === 'rejected',
  'bg-amber-100 text-amber-800': s === 'logged',
  'bg-gray-100 text-gray-700': s === 'manual',
})

const formatT = (t: string | null) => {
  if (!t) return ''
  const [hRaw, mRaw] = String(t).split(':')
  const h = Number(hRaw)
  if (Number.isNaN(h)) return ''
  const ampm = h >= 12 ? 'PM' : 'AM'
  return `${h % 12 === 0 ? 12 : h % 12}:${String(Number(mRaw || 0)).padStart(2, '0')} ${ampm}`
}
const timeLabel = (row: any) => {
  if (row.type === 'arrive_late' || row.type === 'manual_arrive_late') return row.endTime || row.startTime ? `arrives ${formatT(row.endTime || row.startTime)}` : ''
  if (row.type === 'leave_early' || row.type === 'manual_leave_early') return row.startTime ? `leaves ${formatT(row.startTime)}` : ''
  if (row.startTime && row.endTime) return `${formatT(row.startTime)} – ${formatT(row.endTime)}`
  return ''
}

const shortDate = (d: string | null) => {
  if (!d) return ''
  const [y, m, day] = d.split('-').map(Number)
  return new Date(y, m - 1, day).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}
const longDate = (d: string) => {
  const [y, m, day] = d.split('-').map(Number)
  return new Date(y, m - 1, day).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

// --- performance: errors -------------------------------------------------------
const ERROR_TYPES = ['wrong item', 'wrong quantity', 'wrong location', 'damaged', 'mislabeled', 'short pick']

const todayStr = () => toStr(new Date())

const showErrorForm = ref(false)
const savingError = ref(false)
const errorFormError = ref('')
const errorForm = ref({
  error_date: todayStr(),
  job_function_id: '',
  error_count: 1,
  error_type: '',
  notes: '',
})

const submitError = async () => {
  savingError.value = true
  errorFormError.value = ''
  try {
    await $fetch('/api/performance/errors', {
      method: 'POST',
      body: { employee_id: employeeId.value, ...errorForm.value },
    })
    errorForm.value = { error_date: todayStr(), job_function_id: '', error_count: 1, error_type: '', notes: '' }
    showErrorForm.value = false
    await load()
  } catch (e: any) {
    errorFormError.value = e.data?.message || e.message || 'Could not save'
  } finally {
    savingError.value = false
  }
}

// Deletions are confirmed through an in-app dialog rather than window.confirm, so
// the exact record being removed is shown before it goes.
const pendingDelete = ref<{
  title: string
  message: string
  detail: string
  sub?: string
  run: () => Promise<any>
} | null>(null)
const deleting = ref(false)

const confirmDelete = async () => {
  const p = pendingDelete.value
  if (!p) return
  deleting.value = true
  try {
    await p.run()
    pendingDelete.value = null
    await load()
  } catch (e: any) {
    error.value = e.data?.message || e.message || 'Could not delete'
    pendingDelete.value = null
  } finally {
    deleting.value = false
  }
}

const deleteError = (e: any) => {
  const bits = [shortDate(e.error_date), e.job_function_name || 'Unspecified']
  if (e.error_count > 1) bits.push(`×${e.error_count}`)
  if (e.error_type) bits.push(e.error_type)
  pendingDelete.value = {
    title: 'Delete this logged error?',
    message: 'It will be removed from the trend and the totals. This cannot be undone.',
    detail: bits.join(' · '),
    sub: e.notes || (e.logged_by ? `Logged by ${e.logged_by}` : undefined),
    run: () => $fetch(`/api/performance/errors/${e.id}`, { method: 'DELETE' }),
  }
}

// --- Rolling 30-day trend chart -----------------------------------------------
// Plotted in a fixed viewBox and stretched to the card width, so the geometry
// below is in chart units, not pixels.
const CHART = { w: 900, h: 180, padL: 32, padR: 16, padT: 14, padB: 26 }

const hoverPoint = ref<any>(null)

const chartMax = computed(() => {
  const t = data.value?.performance?.trend ?? []
  return Math.max(...t.map((p: any) => p.count), 1)
})

const chartPoints = computed(() => {
  const t = data.value?.performance?.trend ?? []
  if (!t.length) return []
  const max = chartMax.value
  const plotW = CHART.w - CHART.padL - CHART.padR
  const plotH = CHART.h - CHART.padT - CHART.padB
  return t.map((p: any, i: number) => ({
    ...p,
    x: CHART.padL + (t.length === 1 ? plotW / 2 : (i / (t.length - 1)) * plotW),
    y: CHART.h - CHART.padB - (p.count / max) * plotH,
  }))
})

const chartLine = computed(() =>
  chartPoints.value.map((p, i) => `${i ? 'L' : 'M'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join('')
)

const chartArea = computed(() => {
  const pts = chartPoints.value
  if (!pts.length) return ''
  const base = CHART.h - CHART.padB
  return `${chartLine.value}L${pts[pts.length - 1].x.toFixed(1)},${base}L${pts[0].x.toFixed(1)},${base}Z`
})

// Integer ticks only — a count of 2.5 errors is meaningless.
const chartTicks = computed(() => {
  const max = chartMax.value
  const step = Math.max(1, Math.ceil(max / 4))
  const plotH = CHART.h - CHART.padT - CHART.padB
  const out = []
  for (let v = 0; v <= max; v += step) {
    out.push({ v, y: CHART.h - CHART.padB - (v / max) * plotH })
  }
  return out
})

const chartXLabels = computed(() => {
  const pts = chartPoints.value
  if (!pts.length) return []
  const every = Math.max(1, Math.ceil(pts.length / 6))
  return pts
    .filter((_, i) => i % every === 0 || i === pts.length - 1)
    .map((p) => {
      const [y, m, d] = p.date.split('-').map(Number)
      return { x: p.x, label: new Date(y, m - 1, d).toLocaleDateString('en-US', { month: 'short' }) }
    })
})

const chartHitWidth = computed(() => {
  const n = chartPoints.value.length
  if (n < 2) return 40
  return (CHART.w - CHART.padL - CHART.padR) / (n - 1)
})

// --- performance: notes --------------------------------------------------------
const showNoteForm = ref(false)
const savingNote = ref(false)
const noteFormError = ref('')
const noteForm = ref({ note_date: todayStr(), category: 'general', body: '' })

const submitNote = async () => {
  savingNote.value = true
  noteFormError.value = ''
  try {
    await $fetch('/api/performance/notes', {
      method: 'POST',
      body: { employee_id: employeeId.value, ...noteForm.value },
    })
    noteForm.value = { note_date: todayStr(), category: 'general', body: '' }
    showNoteForm.value = false
    await load()
  } catch (e: any) {
    noteFormError.value = e.data?.message || e.message || 'Could not save'
  } finally {
    savingNote.value = false
  }
}

const deleteNote = (n: any) => {
  pendingDelete.value = {
    title: 'Delete this note?',
    message: 'Review notes cannot be recovered once deleted.',
    detail: n.body,
    sub: `${n.category} · ${shortDate(n.note_date)} · ${n.author}`,
    run: () => $fetch(`/api/performance/notes/${n.id}`, { method: 'DELETE' }),
  }
}

const noteCategoryClass = (c: string) => ({
  'bg-green-100 text-green-800': c === 'positive',
  'bg-blue-100 text-blue-800': c === 'coaching',
  'bg-amber-100 text-amber-800': c === 'concern',
  'bg-gray-100 text-gray-700': c === 'general',
})

const noteRailClass = (c: string) => ({
  'border-l-green-500': c === 'positive',
  'border-l-blue-500': c === 'coaching',
  'border-l-amber-500': c === 'concern',
  'border-l-gray-300': c === 'general',
})

// --- Quick-add notes -----------------------------------------------------------
// One click logs the note against today. `tag` is what makes repeats countable —
// free text can't be tallied, and "late from break x5" is what a review needs.
// To change this list, edit here; making it team-configurable is a small follow-up.
const QUICK_NOTES = [
  { tag: 'early_to_break',  label: 'Early to break',    category: 'concern',  body: 'Left for break early.' },
  { tag: 'late_from_break', label: 'Late from break',   category: 'concern',  body: 'Returned from break late.' },
  { tag: 'late_from_lunch', label: 'Late from lunch',   category: 'concern',  body: 'Returned from lunch late.' },
  { tag: 'not_on_task',     label: 'Not on task',       category: 'concern',  body: 'Observed off task during the shift.' },
  { tag: 'late_start',      label: 'Late start',        category: 'concern',  body: 'Started the shift late.' },

  { tag: 'good_work',       label: 'Good work',         category: 'positive', body: 'Recognised for good work.' },
  { tag: 'helped_out',      label: 'Helped out',        category: 'positive', body: 'Volunteered to help cover work.' },
  { tag: 'good_catch',      label: 'Good catch',        category: 'positive', body: 'Caught an issue before it went out the door.' },
  { tag: 'trained_peer',    label: 'Trained a teammate', category: 'positive', body: 'Helped train or coach a teammate.' },
  { tag: 'stayed_late',     label: 'Stayed late',       category: 'positive', body: 'Stayed past scheduled end to finish the work.' },
  { tag: 'took_initiative', label: 'Took initiative',   category: 'positive', body: 'Took initiative without being asked.' },
  { tag: 'strong_day',      label: 'Strong day',        category: 'positive', body: 'Strong output and focus through the shift.' },
]

const quickPositive = QUICK_NOTES.filter((q) => q.category === 'positive')
const quickConcern = QUICK_NOTES.filter((q) => q.category === 'concern')

const quickSaving = ref('')
const quickError = ref('')
const quickToast = ref<{ id: string; label: string } | null>(null)
let quickToastTimer: any = null

const tagCount = (tag: string) =>
  data.value?.performance?.tagCounts?.find((t: any) => t.tag === tag)?.count ?? 0

const quickButtonClass = (category: string) =>
  category === 'positive'
    ? 'border-green-300 bg-white text-green-800 hover:bg-green-50'
    : 'border-amber-300 bg-white text-amber-800 hover:bg-amber-50'

const quickAdd = async (q: { tag: string; label: string; category: string; body: string }) => {
  quickSaving.value = q.tag
  quickError.value = ''
  try {
    const created = await $fetch<any>('/api/performance/notes', {
      method: 'POST',
      body: {
        employee_id: employeeId.value,
        note_date: todayStr(),
        category: q.category,
        body: q.body,
        tag: q.tag,
      },
    })
    // One-click entry is easy to fumble, so offer a short undo window.
    quickToast.value = { id: created.id, label: q.label }
    clearTimeout(quickToastTimer)
    quickToastTimer = setTimeout(() => { quickToast.value = null }, 8000)
    await load()
  } catch (e: any) {
    quickError.value = e.data?.message || e.message || 'Could not log that'
  } finally {
    quickSaving.value = ''
  }
}

const undoQuick = async () => {
  const t = quickToast.value
  if (!t) return
  quickToast.value = null
  clearTimeout(quickToastTimer)
  try {
    await $fetch(`/api/performance/notes/${t.id}`, { method: 'DELETE' })
    await load()
  } catch (e: any) {
    quickError.value = e.data?.message || e.message || 'Could not undo'
  }
}

onBeforeUnmount(() => clearTimeout(quickToastTimer))

// --- export -------------------------------------------------------------------
const esc = (v: any) => {
  const s = String(v ?? '')
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}

const exportCsv = () => {
  if (!data.value) return
  const d = data.value
  const lines: string[] = []

  lines.push(esc(`Employee Overview — ${d.employee.name}`))
  lines.push(esc(`Period,${d.range.from} to ${d.range.to}`))
  lines.push('')

  lines.push('SUMMARY')
  lines.push(['Days scheduled', d.summary.daysScheduled].join(','))
  lines.push(['Hours scheduled', d.summary.hoursScheduled].join(','))
  lines.push(['Avg hours per day', d.summary.avgHoursPerDay].join(','))
  lines.push(['Assignment blocks per day', d.summary.blocksPerDay].join(','))
  lines.push(['Avg block length (h)', d.summary.avgBlockHours].join(','))
  lines.push(['Time off taken (h)', d.summary.absenceHours].join(','))
  lines.push(['Call-ins', d.summary.callIns].join(','))
  lines.push(['Functions worked', d.summary.functionsWorked].join(','))
  lines.push(['Functions trained', d.summary.functionsTrained].join(','))
  lines.push('')

  lines.push('WORK MIX')
  lines.push('Function,Hours,Days,Share %')
  for (const m of d.workMix) lines.push([m.name, m.hours, m.days, m.share].map(esc).join(','))
  lines.push('')

  lines.push('TRAINED BUT NEVER SCHEDULED')
  if (d.skills.neverWorked.length) for (const t of d.skills.neverWorked) lines.push(esc(t.name))
  else lines.push('(none)')
  lines.push('')

  lines.push('ACTIVITY')
  lines.push('Date,Type,Time,Status,Notes')
  for (const r of d.activity) {
    lines.push([r.date, typeLabel(r.type), timeLabel(r), statusLabel(r.status), r.notes || ''].map(esc).join(','))
  }

  // Admin-only sections; d.performance is null for everyone else.
  if (d.performance) {
    lines.push('')
    lines.push('ERRORS LOGGED')
    lines.push('Date,Function,Count,Type,Notes,Logged by')
    if (d.performance.errors.length) {
      for (const e of d.performance.errors) {
        lines.push([e.error_date, e.job_function_name || 'Unspecified', e.error_count,
          e.error_type || '', e.notes || '', e.logged_by || ''].map(esc).join(','))
      }
    } else lines.push('(none)')

    lines.push('')
    lines.push('PERFORMANCE NOTES')
    lines.push('Date,Category,Note,Author')
    if (d.performance.notes.length) {
      for (const n of d.performance.notes) {
        lines.push([n.note_date, n.category, n.body, n.author].map(esc).join(','))
      }
    } else lines.push('(none)')
  }

  // UTF-8 BOM so Excel decodes accented names rather than treating them as Windows-1252.
  const blob = new Blob([String.fromCharCode(0xFEFF) + lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `overview-${d.employee.name.replace(/[^a-z0-9]+/gi, '_')}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

onMounted(async () => {
  await Promise.all([
    employees.value?.length ? Promise.resolve() : fetchEmployees(),
    jobFunctions.value?.length ? Promise.resolve() : fetchJobFunctions(),
  ])
  if (employeeId.value) await load()
})
</script>
