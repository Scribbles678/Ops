export const useTeamSettings = () => {
  const settings = ref<Record<string, string>>({})
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchSettings = async () => {
    loading.value = true
    error.value = null
    try {
      const rows = await $fetch<any[]>('/api/team-settings')
      const map: Record<string, string> = {}
      for (const row of rows) {
        map[row.setting_key] = row.setting_value
      }
      settings.value = map
      return settings.value
    } catch (e: any) {
      error.value = e.message
      return {}
    } finally {
      loading.value = false
    }
  }

  const saveSetting = async (key: string, value: string | number) => {
    loading.value = true
    error.value = null
    try {
      await $fetch('/api/team-settings', {
        method: 'POST',
        body: { setting_key: key, setting_value: String(value) },
      })
      settings.value[key] = String(value)
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  const getSetting = (key: string, defaultValue: string = '0'): string => {
    return settings.value[key] ?? defaultValue
  }

  const getSettingNumber = (key: string, defaultValue: number = 0): number => {
    const val = parseInt(settings.value[key] ?? '', 10)
    return isNaN(val) ? defaultValue : val
  }

  return {
    settings,
    loading,
    error,
    fetchSettings,
    saveSetting,
    getSetting,
    getSettingNumber,
  }
}
