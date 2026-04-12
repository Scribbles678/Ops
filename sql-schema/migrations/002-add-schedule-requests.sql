-- Unified table for PTO, leave-early, and shift-swap requests with auto-approval tracking.
CREATE TABLE IF NOT EXISTS schedule_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  request_type VARCHAR(30) NOT NULL
    CHECK (request_type IN ('leave_early', 'pto_full_day', 'pto_partial', 'shift_swap')),
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  request_date DATE NOT NULL,
  start_time TIME,
  end_time TIME,
  original_shift_id UUID REFERENCES shifts(id),
  requested_shift_id UUID REFERENCES shifts(id),
  approval_rule_results JSONB,
  approved_by UUID,
  admin_override BOOLEAN DEFAULT FALSE,
  rejection_reason TEXT,
  created_pto_id UUID,
  created_swap_id UUID,
  notes TEXT,
  submitted_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_schedule_requests_employee_date ON schedule_requests(employee_id, request_date);
CREATE INDEX IF NOT EXISTS idx_schedule_requests_team_status ON schedule_requests(team_id, status);
CREATE INDEX IF NOT EXISTS idx_schedule_requests_date ON schedule_requests(request_date);
