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
      error.value = e.data?.message ?? e.message
      return {}
    } finally {
      loading.value = false
    }
  }

  /**
   * Save the whole Request Rules form in ONE request — all of it or none (the server
   * checks every value against utils/requestRuleSettings.ts). Uses `saving`, not
   * `loading`: sharing `loading` made the form vanish behind "Loading settings…"
   * on every save. Throws on failure; the caller shows the server's message.
   */
  const saving = ref(false)
  const saveRules = async (values: Record<string, unknown>) => {
    saving.value = true
    try {
      const saved = await $fetch<Record<string, string>>('/api/team-settings', {
        method: 'POST',
        body: { settings: values },
      })
      settings.value = { ...settings.value, ...saved }
      return settings.value
    } finally {
      saving.value = false
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
    saving,
    error,
    fetchSettings,
    saveRules,
    getSetting,
    getSettingNumber,
  }
}
