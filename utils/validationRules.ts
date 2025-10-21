export const validateAssignment = (
  assignment: any,
  existingAssignments: any[],
  employeeTraining: string[]
): { valid: boolean; errors: string[] } => {
  const errors: string[] = []

  // Rule 1: Employee must be trained in the job function
  if (!employeeTraining.includes(assignment.job_function_id)) {
    errors.push('Employee is not trained in this job function')
  }

  // Rule 2: Assignment duration must be at least 30 minutes
  const startMinutes = timeToMinutes(assignment.start_time)
  const endMinutes = timeToMinutes(assignment.end_time)
  const durationMinutes = endMinutes - startMinutes

  if (durationMinutes < 30) {
    errors.push('Assignment duration must be at least 30 minutes')
  }

  // Rule 3: Employee cannot be assigned to multiple jobs at the same time
  const hasTimeConflict = existingAssignments.some(existing => {
    if (existing.id === assignment.id) return false // Skip self when editing
    if (existing.employee_id !== assignment.employee_id) return false
    if (existing.schedule_date !== assignment.schedule_date) return false

    const existingStart = timeToMinutes(existing.start_time)
    const existingEnd = timeToMinutes(existing.end_time)

    // Check for time overlap
    return (
      (startMinutes >= existingStart && startMinutes < existingEnd) ||
      (endMinutes > existingStart && endMinutes <= existingEnd) ||
      (startMinutes <= existingStart && endMinutes >= existingEnd)
    )
  })

  if (hasTimeConflict) {
    errors.push('Employee is already assigned to another job during this time')
  }

  return {
    valid: errors.length === 0,
    errors
  }
}

export const timeToMinutes = (time: string): number => {
  const [hours, minutes] = time.split(':').map(Number)
  return hours * 60 + minutes
}

export const minutesToTime = (minutes: number): string => {
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:00`
}

export const isBreakTime = (
  time: string,
  shift: any
): { isBreak: boolean; type: string } => {
  if (!shift) return { isBreak: false, type: '' }

  const timeMinutes = timeToMinutes(time)

  // Check Break 1
  if (shift.break_1_start && shift.break_1_end) {
    const break1Start = timeToMinutes(shift.break_1_start)
    const break1End = timeToMinutes(shift.break_1_end)
    if (timeMinutes >= break1Start && timeMinutes < break1End) {
      return { isBreak: true, type: 'Break' }
    }
  }

  // Check Break 2
  if (shift.break_2_start && shift.break_2_end) {
    const break2Start = timeToMinutes(shift.break_2_start)
    const break2End = timeToMinutes(shift.break_2_end)
    if (timeMinutes >= break2Start && timeMinutes < break2End) {
      return { isBreak: true, type: 'Break' }
    }
  }

  // Check Lunch
  if (shift.lunch_start && shift.lunch_end) {
    const lunchStart = timeToMinutes(shift.lunch_start)
    const lunchEnd = timeToMinutes(shift.lunch_end)
    if (timeMinutes >= lunchStart && timeMinutes < lunchEnd) {
      return { isBreak: true, type: 'Lunch' }
    }
  }

  return { isBreak: false, type: '' }
}

