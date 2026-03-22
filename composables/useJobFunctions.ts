export const useJobFunctions = () => {
  const jobFunctions = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchJobFunctions = async () => {
    loading.value = true
    error.value = null
    try {
      jobFunctions.value = await $fetch<any[]>('/api/job-functions')
      return jobFunctions.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
    }
  }

  const createJobFunction = async (data: any) => {
    loading.value = true
    error.value = null
    try {
      const result = await $fetch('/api/job-functions', { method: 'POST', body: data })
      await fetchJobFunctions()
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const updateJobFunction = async (id: string, data: any) => {
    loading.value = true
    error.value = null
    try {
      const result = await $fetch(`/api/job-functions/${id}`, { method: 'PUT', body: data })
      await fetchJobFunctions()
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteJobFunction = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/job-functions/${id}`, { method: 'DELETE' })
      await fetchJobFunctions()
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  // Meter job function helpers (unchanged logic, no Supabase dependency)
  const isMeterJobFunction = (name: string) => name.startsWith('Meter ')
  const getMeterNumber = (name: string) => {
    const match = name.match(/^Meter (\d+)$/)
    return match ? parseInt(match[1]) : null
  }
  const getGroupedJobFunctions = () => {
    const meters = jobFunctions.value.filter((jf) => isMeterJobFunction(jf.name))
    const nonMeters = jobFunctions.value.filter((jf) => !isMeterJobFunction(jf.name))
    const grouped = [...nonMeters]
    if (meters.length > 0) {
      grouped.push({ id: 'meter-group', name: 'Meter', _isGroup: true, _meters: meters })
    }
    return grouped
  }
  const getAllMeterJobFunctions = () => jobFunctions.value.filter((jf) => isMeterJobFunction(jf.name))
  const getMeterJobFunctionByNumber = (num: number) =>
    jobFunctions.value.find((jf) => jf.name === `Meter ${num}`) ?? null

  return {
    jobFunctions,
    loading,
    error,
    fetchJobFunctions,
    createJobFunction,
    updateJobFunction,
    deleteJobFunction,
    isMeterJobFunction,
    getMeterNumber,
    getGroupedJobFunctions,
    getAllMeterJobFunctions,
    getMeterJobFunctionByNumber,
  }
}
