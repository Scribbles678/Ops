<template>
  <div>
    <div class="flex justify-between items-center mb-3">
      <h2 class="text-lg md:text-xl font-semibold text-gray-800">Productivity Rates</h2>
      <p class="text-[11px] md:text-xs text-gray-500">Set production targets for each job function</p>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="text-center py-6">
      <p class="text-gray-600">Loading job functions...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-3 mb-3 text-sm">
      <p class="text-red-600">{{ error }}</p>
    </div>

    <!-- Productivity Rates Table -->
    <div v-else class="space-y-3">
      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden text-sm">
        <div class="bg-gray-50 px-4 md:px-6 py-3 border-b border-gray-200">
          <div class="grid grid-cols-12 gap-3 font-medium text-gray-700 text-xs md:text-sm">
            <div class="col-span-4">Job Function</div>
            <div class="col-span-3">Production Rate</div>
            <div class="col-span-3">Unit of Measure</div>
            <div class="col-span-2 text-center">Actions</div>
          </div>
        </div>
        
        <div class="divide-y divide-gray-200">
          <div
            v-for="jobFunction in jobFunctions"
            :key="jobFunction.id"
            class="px-4 md:px-6 py-3 hover:bg-gray-50"
          >
            <div class="grid grid-cols-12 gap-3 items-center">
              <!-- Job Function Name with Color -->
              <div class="col-span-4 flex items-center space-x-3">
                <div
                  class="w-3.5 h-3.5 md:w-4 md:h-4 rounded border border-gray-300"
                  :style="{ backgroundColor: jobFunction.color_code }"
                ></div>
                <span class="font-medium text-gray-800 text-xs md:text-sm">{{ jobFunction.name }}</span>
              </div>
              
              <!-- Production Rate Input -->
              <div class="col-span-3">
                <input
                  :value="jobFunction.productivity_rate || ''"
                  @change="updateProductivityRate(jobFunction.id, $event)"
                  type="number"
                  min="0"
                  step="1"
                  placeholder="Enter rate"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                />
              </div>
              
              <!-- Unit of Measure -->
              <div class="col-span-3">
                <select
                  :value="getUnitOfMeasure(jobFunction.id)"
                  @change="updateUnitOfMeasure(jobFunction.id, $event)"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                >
                  <option value="">Select unit</option>
                  <option value="cartons/hour">Cartons/Hour</option>
                  <option value="boxes/hour">Boxes/Hour</option>
                  <option value="units/hour">Units/Hour</option>
                  <option value="pieces/hour">Pieces/Hour</option>
                  <option value="orders/hour">Orders/Hour</option>
                  <option value="pallets/hour">Pallets/Hour</option>
                  <option value="cases/hour">Cases/Hour</option>
                  <option value="items/hour">Items/Hour</option>
                  <option value="custom">Custom</option>
                </select>
              </div>
              
              <!-- Actions -->
              <div class="col-span-2 text-center">
                <button
                  @click="saveJobFunctionSettings(jobFunction.id)"
                  class="px-2.5 py-1 bg-green-100 text-green-600 rounded hover:bg-green-200 transition text-xs md:text-sm"
                >
                  Save
                </button>
              </div>
            </div>
            
            <!-- Custom Unit Input (shown when "Custom" is selected) -->
            <div v-if="getUnitOfMeasure(jobFunction.id) === 'custom'" class="mt-2 col-span-12">
              <div class="flex items-center space-x-2 text-xs md:text-sm">
                <label class="text-gray-600">Custom Unit:</label>
                <input
                  :value="getCustomUnit(jobFunction.id)"
                  @change="updateCustomUnit(jobFunction.id, $event)"
                  type="text"
                  placeholder="Enter custom unit"
                  class="px-3 py-1 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Summary -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-3 md:p-4 text-[11px] md:text-sm">
        <h3 class="font-semibold text-blue-800 mb-2 text-xs md:text-sm">💡 Tips for Setting Productivity Rates</h3>
        <ul class="text-blue-700 space-y-1">
          <li>• Base rates on historical performance data when available</li>
          <li>• Consider different skill levels and experience</li>
          <li>• Adjust for peak vs. normal operational periods</li>
          <li>• Review and update rates regularly based on performance</li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { jobFunctions, loading, error, fetchJobFunctions, updateJobFunction } = useJobFunctions()

const jobFunctionSettings = ref<Record<string, any>>({})

onMounted(() => {
  fetchJobFunctions()
})

const getUnitOfMeasure = (jobFunctionId: string): string => {
  return jobFunctionSettings.value[jobFunctionId]?.unit_of_measure || ''
}

const getCustomUnit = (jobFunctionId: string): string => {
  return jobFunctionSettings.value[jobFunctionId]?.custom_unit || ''
}

const updateProductivityRate = (jobFunctionId: string, event: Event) => {
  const value = parseInt((event.target as HTMLInputElement).value) || null
  
  if (!jobFunctionSettings.value[jobFunctionId]) {
    jobFunctionSettings.value[jobFunctionId] = {}
  }
  jobFunctionSettings.value[jobFunctionId].productivity_rate = value
}

const updateUnitOfMeasure = (jobFunctionId: string, event: Event) => {
  const value = (event.target as HTMLSelectElement).value
  
  if (!jobFunctionSettings.value[jobFunctionId]) {
    jobFunctionSettings.value[jobFunctionId] = {}
  }
  jobFunctionSettings.value[jobFunctionId].unit_of_measure = value
}

const updateCustomUnit = (jobFunctionId: string, event: Event) => {
  const value = (event.target as HTMLInputElement).value
  
  if (!jobFunctionSettings.value[jobFunctionId]) {
    jobFunctionSettings.value[jobFunctionId] = {}
  }
  jobFunctionSettings.value[jobFunctionId].custom_unit = value
}

const saveJobFunctionSettings = async (jobFunctionId: string) => {
  try {
    const settings = jobFunctionSettings.value[jobFunctionId]
    if (settings) {
      await updateJobFunction(jobFunctionId, {
        productivity_rate: settings.productivity_rate,
        unit_of_measure: settings.unit_of_measure,
        custom_unit: settings.custom_unit
      })
      
      // Show success message
      console.log('Settings saved successfully!')
    }
  } catch (e) {
    console.error('Error saving settings:', e)
  }
}
</script>
