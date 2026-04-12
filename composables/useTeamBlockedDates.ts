export interface BlockedDate {
  id: string
  team_id: string
  blocked_date: string // YYYY-MM-DD (or ISO-ish — server returns a DATE, Postgres driver may format as ISO)
  reason: string | null
  created_at: string
}

export const useTeamBlockedDates = () => {
  const blockedDates = ref<BlockedDate[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchBlockedDates = async () => {
    loading.value = true
    error.value = null
    try {
      blockedDates.value = await $fetch<BlockedDate[]>('/api/team-blocked-dates')
      return blockedDates.value
    } catch (e: any) {
      error.value = e?.data?.message || e?.message || 'Failed to load blocked dates'
      return []
    } finally {
      loading.value = false
    }
  }

  const addBlockedDates = async (dates: string[], reason?: string | null) => {
    loading.value = true
    error.value = null
    try {
      const res = await $fetch<{ inserted: BlockedDate[]; count: number }>(
        '/api/team-blocked-dates',
        { method: 'POST', body: { dates, reason: reason ?? null } }
      )
      await fetchBlockedDates()
      return res
    } catch (e: any) {
      error.value = e?.data?.message || e?.message || 'Failed to add blocked dates'
      throw e
    } finally {
      loading.value = false
    }
  }

  const removeBlockedDate = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/team-blocked-dates/${id}`, { method: 'DELETE' })
      blockedDates.value = blockedDates.value.filter((d) => d.id !== id)
      return true
    } catch (e: any) {
      error.value = e?.data?.message || e?.message || 'Failed to remove blocked date'
      return false
    } finally {
      loading.value = false
    }
  }

  // Date helpers: build business-day lists relative to period ends.
  // "Business days" = Mon-Fri (no holiday awareness — add later if needed).
  const BUSINESS_DAYS = new Set([1, 2, 3, 4, 5])

  const toYMD = (d: Date): string => {
    const y = d.getFullYear()
    const m = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    return `${y}-${m}-${day}`
  }

  // Return the last N business days (Mon-Fri) on or before endDate, newest → oldest.
  const lastNBusinessDays = (endDate: Date, n: number): string[] => {
    const out: string[] = []
    const cursor = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate())
    let safety = 0
    while (out.length < n && safety < 365) {
      if (BUSINESS_DAYS.has(cursor.getDay())) {
        out.push(toYMD(cursor))
      }
      cursor.setDate(cursor.getDate() - 1)
      safety++
    }
    return out
  }

  // Last day of a given month (0-indexed month, JS style)
  const endOfMonth = (year: number, month: number): Date => {
    return new Date(year, month + 1, 0) // day 0 of next month = last day of current
  }

  // Last day of a given quarter (quarter 1..4)
  const endOfQuarter = (year: number, quarter: number): Date => {
    const lastMonth = quarter * 3 - 1 // Q1→Feb (month 2), Q2→May (5), Q3→Aug (8), Q4→Nov (11)
    return endOfMonth(year, lastMonth)
  }

  // Generate blocked dates for last N business days of specified quarters in a year.
  const buildQuarterEndDates = (year: number, quarters: number[], n: number): string[] => {
    const out = new Set<string>()
    for (const q of quarters) {
      if (q < 1 || q > 4) continue
      const end = endOfQuarter(year, q)
      for (const d of lastNBusinessDays(end, n)) out.add(d)
    }
    return Array.from(out).sort()
  }

  // Generate blocked dates for last N business days of specified months in a year.
  const buildMonthEndDates = (year: number, months: number[], n: number): string[] => {
    const out = new Set<string>()
    for (const m of months) {
      if (m < 1 || m > 12) continue
      const end = endOfMonth(year, m - 1)
      for (const d of lastNBusinessDays(end, n)) out.add(d)
    }
    return Array.from(out).sort()
  }

  return {
    blockedDates,
    loading,
    error,
    fetchBlockedDates,
    addBlockedDates,
    removeBlockedDate,
    buildQuarterEndDates,
    buildMonthEndDates,
  }
}
