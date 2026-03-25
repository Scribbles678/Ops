<template>
  <div
    class="rounded-lg p-4 border"
    :class="status === 'approved'
      ? 'bg-green-50 border-green-200'
      : 'bg-red-50 border-red-200'"
  >
    <div class="flex items-center gap-2 mb-2">
      <div
        class="w-8 h-8 rounded-full flex items-center justify-center text-white text-lg"
        :class="status === 'approved' ? 'bg-green-500' : 'bg-red-500'"
      >
        {{ status === 'approved' ? '✓' : '✗' }}
      </div>
      <h3 class="font-semibold text-lg" :class="status === 'approved' ? 'text-green-800' : 'text-red-800'">
        {{ status === 'approved' ? 'Request Approved' : 'Request Rejected' }}
      </h3>
    </div>

    <p v-if="rejectionReason" class="text-sm text-red-700 mb-3">{{ rejectionReason }}</p>

    <!-- Rule breakdown -->
    <div v-if="ruleResults && Object.keys(ruleResults).length > 0" class="space-y-1">
      <p class="text-xs font-medium text-gray-600 mb-1">Rule checks:</p>
      <div v-for="(passed, rule) in ruleResults" :key="rule" class="flex items-center gap-2 text-sm">
        <span :class="passed ? 'text-green-600' : 'text-red-600'">
          {{ passed ? '✓' : '✗' }}
        </span>
        <span :class="passed ? 'text-gray-700' : 'text-red-700'">{{ ruleLabel(String(rule)) }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  status: 'approved' | 'rejected'
  ruleResults: Record<string, boolean> | null
  rejectionReason?: string | null
}>()

const ruleLabels: Record<string, string> = {
  '24h_advance': '24-hour advance notice',
  'max_leave_early_per_day': 'Leave-early limit per day',
  'max_shift_swap_per_day': 'Shift change limit per day',
  'max_pto_hours_per_day': 'Team PTO hours limit per day',
  'max_shift_swaps_per_day': 'Shift swaps limit per day',
}

const ruleLabel = (key: string) => ruleLabels[key] || key
</script>
