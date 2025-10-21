export const useLaborCalculations = () => {
  
  const calculateHoursBetween = (startTime: string, endTime: string): number => {
    const [startHour, startMin] = startTime.split(':').map(Number)
    const [endHour, endMin] = endTime.split(':').map(Number)
    
    const startMinutes = startHour * 60 + startMin
    const endMinutes = endHour * 60 + endMin
    
    return (endMinutes - startMinutes) / 60
  }

  const calculateScheduledHours = (assignments: any[], jobFunctionId: string): number => {
    return assignments
      .filter(a => a.job_function_id === jobFunctionId)
      .reduce((total, assignment) => {
        const hours = calculateHoursBetween(assignment.start_time, assignment.end_time)
        return total + hours
      }, 0)
  }

  const calculateRequiredHours = (targetUnits: number, productivityRate: number): number => {
    if (!productivityRate || productivityRate === 0) return 0
    return targetUnits / productivityRate
  }

  const calculateStaffingStatus = (scheduledHours: number, requiredHours: number): {
    status: 'understaffed-critical' | 'understaffed' | 'adequate' | 'overstaffed',
    percentage: number,
    difference: number
  } => {
    if (requiredHours === 0) {
      return {
        status: 'adequate',
        percentage: 100,
        difference: 0
      }
    }

    const difference = scheduledHours - requiredHours
    const percentage = (scheduledHours / requiredHours) * 100

    let status: 'understaffed-critical' | 'understaffed' | 'adequate' | 'overstaffed'
    
    if (percentage < 80) {
      status = 'understaffed-critical'
    } else if (percentage < 95) {
      status = 'understaffed'
    } else if (percentage <= 105) {
      status = 'adequate'
    } else {
      status = 'overstaffed'
    }

    return {
      status,
      percentage: Math.round(percentage),
      difference: Math.round(difference * 10) / 10
    }
  }

  const getStatusColor = (status: string): string => {
    switch (status) {
      case 'understaffed-critical':
        return 'bg-red-500'
      case 'understaffed':
        return 'bg-yellow-500'
      case 'adequate':
        return 'bg-green-500'
      case 'overstaffed':
        return 'bg-blue-500'
      default:
        return 'bg-gray-500'
    }
  }

  const getStatusText = (status: string): string => {
    switch (status) {
      case 'understaffed-critical':
        return 'Critical - Need more staff'
      case 'understaffed':
        return 'Understaffed'
      case 'adequate':
        return 'Adequately Staffed'
      case 'overstaffed':
        return 'Overstaffed'
      default:
        return 'Unknown'
    }
  }

  const formatTime = (time: string): string => {
    const [hours, minutes] = time.split(':')
    const hour = parseInt(hours)
    const ampm = hour >= 12 ? 'PM' : 'AM'
    const displayHour = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour
    return `${displayHour}:${minutes} ${ampm}`
  }

  const formatDate = (date: string | Date): string => {
    const d = new Date(date)
    return d.toLocaleDateString('en-US', { 
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    })
  }

  return {
    calculateHoursBetween,
    calculateScheduledHours,
    calculateRequiredHours,
    calculateStaffingStatus,
    getStatusColor,
    getStatusText,
    formatTime,
    formatDate
  }
}

