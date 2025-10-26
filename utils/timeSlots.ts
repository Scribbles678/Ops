// Utility functions for 15-minute time slot management

export interface TimeSlot {
  id: string
  time: string
  displayTime: string
  isBreakTime: boolean
  breakType?: 'break1' | 'break2' | 'lunch'
}

export const generateTimeSlots = (startHour: number = 6, endHour: number = 20, shifts: any[] = []): TimeSlot[] => {
  const slots: TimeSlot[] = []
  
  for (let hour = startHour; hour < endHour; hour++) {
    for (let quarter = 0; quarter < 4; quarter++) {
      const minutes = quarter * 15
      const timeString = `${hour.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`
      
      // Convert to 12-hour format for display
      const displayHour = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour
      const ampm = hour >= 12 ? 'PM' : 'AM'
      const displayTime = `${displayHour}:${minutes.toString().padStart(2, '0')} ${ampm}`
      
      // Determine if this is a break time using shift data
      const isBreakTime = isBreakPeriodWithShifts(hour, minutes, shifts)
      const breakType = getBreakTypeWithShifts(hour, minutes, shifts)
      
      slots.push({
        id: timeString,
        time: timeString,
        displayTime,
        isBreakTime,
        breakType
      })
    }
  }
  
  return slots
}

// Determine if a time slot is a break period using shift data
const isBreakPeriodWithShifts = (hour: number, minutes: number, shifts: any[]): boolean => {
  if (!shifts || shifts.length === 0) {
    return false
  }
  
  const timeString = `${hour.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`
  const timeMinutes = hour * 60 + minutes
  
  // Check each shift for break times
  for (const shift of shifts) {
    // Only debug the 6 AM shift
    if (shift.name !== '6:00 AM - 2:30 PM') {
      continue
    }
    
    // Helper function to convert time string to minutes
    const convertTimeToMinutes = (timeStr: string | null | undefined): number | null => {
      if (!timeStr) return null
      let cleanTime = timeStr.toString().trim()
      if (cleanTime.includes(':')) {
        const parts = cleanTime.split(':')
        if (parts.length === 3) {
          cleanTime = `${parts[0]}:${parts[1]}`
        }
      }
      const [hours, mins] = cleanTime.split(':').map(Number)
      return hours * 60 + mins
    }
    
    const break1Start = convertTimeToMinutes(shift.break_1_start)
    const break1End = convertTimeToMinutes(shift.break_1_end)
    const break2Start = convertTimeToMinutes(shift.break_2_start)
    const break2End = convertTimeToMinutes(shift.break_2_end)
    const lunchStart = convertTimeToMinutes(shift.lunch_start)
    const lunchEnd = convertTimeToMinutes(shift.lunch_end)
    
    // Debug logging only for specific break time slots
    if (timeString === '07:30' || timeString === '07:45' || timeString === '08:00' || 
        timeString === '09:30' || timeString === '09:45' || timeString === '10:00' ||
        timeString === '12:30' || timeString === '12:45' || timeString === '13:00') {
      console.log(`🔍 6AM Shift - Checking: ${timeString} (${timeMinutes} minutes)`)
      console.log(`  Break 1: ${shift.break_1_start} -> ${break1Start} to ${break1End}`)
      console.log(`  Break 2: ${shift.break_2_start} -> ${break2Start} to ${break2End}`)
      console.log(`  Lunch: ${shift.lunch_start} -> ${lunchStart} to ${lunchEnd}`)
    }
    
    // Check if this time slot falls within any break period
    if ((break1Start !== null && break1End !== null && timeMinutes >= break1Start && timeMinutes < break1End) ||
        (break2Start !== null && break2End !== null && timeMinutes >= break2Start && timeMinutes < break2End) ||
        (lunchStart !== null && lunchEnd !== null && timeMinutes >= lunchStart && timeMinutes < lunchEnd)) {
      
      if (timeString === '07:30' || timeString === '07:45' || timeString === '08:00' || 
          timeString === '09:30' || timeString === '09:45' || timeString === '10:00' ||
          timeString === '12:30' || timeString === '12:45' || timeString === '13:00') {
        console.log(`✅ 6AM Shift - ${timeString} is a break time`)
      }
      return true
    }
  }
  
  // Only log if it's one of the break time slots we're checking
  if (timeString === '07:30' || timeString === '07:45' || timeString === '08:00' || 
      timeString === '09:30' || timeString === '09:45' || timeString === '10:00' ||
      timeString === '12:30' || timeString === '12:45' || timeString === '13:00') {
    console.log(`❌ 6AM Shift - ${timeString} is NOT a break time`)
  }
  
  return false
}

// Determine if a time slot is a break period (legacy function)
const isBreakPeriod = (hour: number, minutes: number): boolean => {
  // Common break times (customize based on your shifts)
  const breakTimes = [
    { hour: 7, minutes: 45 }, // 7:45 AM - 8:00 AM
    { hour: 8, minutes: 0 },   // 8:00 AM - 8:15 AM
    { hour: 9, minutes: 45 }, // 9:45 AM - 10:00 AM
    { hour: 10, minutes: 0 },  // 10:00 AM - 10:15 AM
    { hour: 12, minutes: 30 }, // 12:30 PM - 1:00 PM (lunch)
    { hour: 12, minutes: 45 },
    { hour: 13, minutes: 0 },
    { hour: 14, minutes: 45 }, // 2:45 PM - 3:00 PM
    { hour: 15, minutes: 0 },  // 3:00 PM - 3:15 PM
  ]
  
  return breakTimes.some(breakTime => 
    breakTime.hour === hour && breakTime.minutes === minutes
  )
}

// Determine the type of break using shift data
const getBreakTypeWithShifts = (hour: number, minutes: number, shifts: any[]): 'break1' | 'break2' | 'lunch' | undefined => {
  if (!shifts || shifts.length === 0) {
    return undefined
  }
  
  const timeMinutes = hour * 60 + minutes
  
  // Check each shift for break times
  for (const shift of shifts) {
    // Helper function to convert time string to minutes
    const convertTimeToMinutes = (timeStr: string | null | undefined): number | null => {
      if (!timeStr) return null
      let cleanTime = timeStr.toString().trim()
      if (cleanTime.includes(':')) {
        const parts = cleanTime.split(':')
        if (parts.length === 3) {
          cleanTime = `${parts[0]}:${parts[1]}`
        }
      }
      const [hours, mins] = cleanTime.split(':').map(Number)
      return hours * 60 + mins
    }
    
    const break1Start = convertTimeToMinutes(shift.break_1_start)
    const break1End = convertTimeToMinutes(shift.break_1_end)
    const break2Start = convertTimeToMinutes(shift.break_2_start)
    const break2End = convertTimeToMinutes(shift.break_2_end)
    const lunchStart = convertTimeToMinutes(shift.lunch_start)
    const lunchEnd = convertTimeToMinutes(shift.lunch_end)
    
    // Check if this time slot falls within break 1 period
    if (break1Start !== null && break1End !== null && timeMinutes >= break1Start && timeMinutes < break1End) {
      return 'break1'
    }
    
    // Check if this time slot falls within break 2 period
    if (break2Start !== null && break2End !== null && timeMinutes >= break2Start && timeMinutes < break2End) {
      return 'break2'
    }
    
    // Check if this time slot falls within lunch period
    if (lunchStart !== null && lunchEnd !== null && timeMinutes >= lunchStart && timeMinutes < lunchEnd) {
      return 'lunch'
    }
  }
  
  return undefined
}

// Determine the type of break (legacy function)
const getBreakType = (hour: number, minutes: number): 'break1' | 'break2' | 'lunch' | undefined => {
  // Morning break
  if ((hour === 7 && minutes === 45) || (hour === 8 && minutes === 0)) {
    return 'break1'
  }
  
  // Mid-morning break
  if ((hour === 9 && minutes === 45) || (hour === 10 && minutes === 0)) {
    return 'break2'
  }
  
  // Lunch
  if ((hour === 12 && minutes === 30) || (hour === 12 && minutes === 45) || (hour === 13 && minutes === 0)) {
    return 'lunch'
  }
  
  // Afternoon break
  if ((hour === 14 && minutes === 45) || (hour === 15 && minutes === 0)) {
    return 'break1'
  }
  
  return undefined
}

// Format time for display in schedule headers
export const formatTimeForHeader = (time: string): string => {
  const [hours, minutes] = time.split(':').map(Number)
  const displayHour = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours
  const ampm = hours >= 12 ? 'PM' : 'AM'
  
  if (minutes === 0) {
    return `${displayHour} ${ampm}`
  } else {
    return `${displayHour}:${minutes.toString().padStart(2, '0')} ${ampm}`
  }
}

// Get time slot width for CSS (15-minute slots)
export const getTimeSlotWidth = (): string => {
  return 'min-w-[60px]' // Narrower columns for 15-minute slots
}

// Check if a time slot is within a shift
export const isWithinShift = (timeSlot: string, shiftStart: string, shiftEnd: string): boolean => {
  const slotTime = timeSlot.split(':').map(Number)
  const startTime = shiftStart.split(':').map(Number)
  const endTime = shiftEnd.split(':').map(Number)
  
  const slotMinutes = slotTime[0] * 60 + slotTime[1]
  const startMinutes = startTime[0] * 60 + startTime[1]
  const endMinutes = endTime[0] * 60 + endTime[1]
  
  return slotMinutes >= startMinutes && slotMinutes < endMinutes
}
