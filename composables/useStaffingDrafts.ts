export interface StaffingSegment {
  start: string
  end: string
  targetHours: number
}

export function normalizeDbTime(t: string | null | undefined): string {
  if (!t) return '00:00'
  const s = String(t)
  return s.length >= 5 ? s.slice(0, 5) : s
}

function timeToMinutes(time: string): number {
  const parts = String(time || '00:00').split(':').map(Number)
  return (parts[0] || 0) * 60 + (parts[1] || 0)
}

export function slotDurationHours(start: string, end: string): number {
  const a = timeToMinutes(start)
  const b = timeToMinutes(end)
  if (b <= a) return 0
  return (b - a) / 60
}

/**
 * Convert live business_rules rows into editor segments (excludes fan-out and global-max-only rows).
 */
export function liveRulesToSegments(rules: any[]): StaffingSegment[] {
  const filtered = (rules || []).filter((r) => {
    if (!r) return false
    if (r.fan_out_enabled) return false
    if (r.min_staff == null && r.max_staff != null) return false
    return r.min_staff != null || r.max_staff != null
  })
  const mapped = filtered
    .sort((a, b) => String(a.time_slot_start).localeCompare(String(b.time_slot_start)))
    .map((r) => {
      const start = normalizeDbTime(r.time_slot_start)
      const end = normalizeDbTime(r.time_slot_end)
      const staff = r.max_staff ?? r.min_staff ?? 1
      const sh = slotDurationHours(start, end)
      const targetHours = sh > 0 ? staff * sh : Number(staff)
      return {
        start,
        end,
        targetHours: Math.round(targetHours * 10) / 10,
      }
    })
  if (mapped.length === 0) {
    return [{ start: '08:00', end: '17:00', targetHours: 8 }]
  }
  return mapped
}

export function useStaffingDrafts() {
  const loading = ref(false)
  const error = ref<string | null>(null)

  const teamQuery = (teamId: string | null | undefined) =>
    teamId ? { team_id: teamId } : ({} as Record<string, string>)

  const fetchDraftPayload = async (jobFunctionName: string, teamId?: string | null) => {
    loading.value = true
    error.value = null
    try {
      const q = new URLSearchParams({
        job_function_name: jobFunctionName,
        ...teamQuery(teamId || undefined),
      })
      return await $fetch<{
        draft: {
          segments: StaffingSegment[]
          updated_at?: string
        } | null
        liveRules: any[]
        teamScope: string | null
      }>(`/api/staffing-drafts?${q.toString()}`)
    } catch (e: any) {
      error.value = e?.data?.message || e?.message || 'Failed to load draft'
      throw e
    } finally {
      loading.value = false
    }
  }

  const fetchDraftList = async (teamId?: string | null) => {
    const q = new URLSearchParams(teamQuery(teamId || undefined))
    const qs = q.toString()
    return await $fetch<{ rows: { job_function_name: string; updated_at: string }[]; teamScope: string | null }>(
      `/api/staffing-drafts/list${qs ? `?${qs}` : ''}`
    )
  }

  const saveDraft = async (
    jobFunctionName: string,
    segments: StaffingSegment[],
    teamId?: string | null
  ) => {
    loading.value = true
    error.value = null
    try {
      return await $fetch('/api/staffing-drafts', {
        method: 'PUT',
        body: {
          job_function_name: jobFunctionName,
          segments,
          team_id: teamId || undefined,
        },
      })
    } catch (e: any) {
      error.value = e?.data?.message || e?.message || 'Failed to save draft'
      throw e
    } finally {
      loading.value = false
    }
  }

  const publishDraft = async (jobFunctionName: string, teamId?: string | null) => {
    loading.value = true
    error.value = null
    try {
      return await $fetch('/api/staffing-drafts/publish', {
        method: 'POST',
        body: {
          job_function_name: jobFunctionName,
          team_id: teamId || undefined,
        },
      })
    } catch (e: any) {
      error.value = e?.data?.message || e?.message || 'Failed to publish'
      throw e
    } finally {
      loading.value = false
    }
  }

  /** Detect overlapping segments (same day, non-empty intersection). */
  const overlapWarnings = (segments: StaffingSegment[]): string[] => {
    const sorted = [...segments].sort((a, b) => timeToMinutes(a.start) - timeToMinutes(b.start))
    const w: string[] = []
    for (let i = 1; i < sorted.length; i++) {
      const prev = sorted[i - 1]
      const cur = sorted[i]
      if (timeToMinutes(cur.start) < timeToMinutes(prev.end)) {
        w.push(`Overlap: ${prev.start}–${prev.end} and ${cur.start}–${cur.end}`)
      }
    }
    return w
  }

  return {
    loading,
    error,
    fetchDraftPayload,
    fetchDraftList,
    saveDraft,
    publishDraft,
    liveRulesToSegments,
    slotDurationHours,
    overlapWarnings,
  }
}
