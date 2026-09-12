/**
 * How a schedule_requests row is labelled for people. One implementation, shared
 * by the PTO calendar's tables and the request modal's "check my requests" tab.
 *
 * Storage convention for a REQUEST row (different from pto_days — see ptoDisplay):
 *   arrive_late   start_time = when they ARRIVE
 *   leave_early   start_time = when they LEAVE
 *   pto_partial   start_time .. end_time
 *   others        no times
 */
import { formatTimeOfDay, ptoTimeToMinutes } from './ptoDisplay'

const REQUEST_TYPE_LABELS: Record<string, string> = {
  leave_early: 'Leave Early',
  leave_on_time: 'Leave on Time',
  arrive_late: 'Arrive Late',
  pto_full_day: 'Full Day Off',
  pto_partial: 'Partial Day',
  shift_swap: 'Shift Change',
}

export const requestTypeLabel = (type: string | null | undefined): string =>
  (type && REQUEST_TYPE_LABELS[type]) || type || ''

const fmt = (t: string | null | undefined): string => {
  const mins = ptoTimeToMinutes(t)
  return mins == null ? '' : formatTimeOfDay(mins)
}

/** "leaves 4:00 PM", "arrives 1:30 PM", "12:00 PM – 3:00 PM", or "" when there is no time detail. */
export const requestTimeLabel = (req: { request_type?: string; start_time?: string | null; end_time?: string | null } | null | undefined): string => {
  if (!req) return ''
  if (req.request_type === 'arrive_late') return req.start_time ? `arrives ${fmt(req.start_time)}` : ''
  if (req.request_type === 'leave_early') return req.start_time ? `leaves ${fmt(req.start_time)}` : ''
  if (req.request_type === 'pto_partial' && req.start_time && req.end_time) return `${fmt(req.start_time)} – ${fmt(req.end_time)}`
  return ''
}
