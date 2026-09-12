-- 022 — Change log (audit trail of manual changes to people's records)
--
-- One row per manual change: who did it, what they did, to whom, and a plain
-- sentence describing it, plus before/after snapshots so a DELETED record can
-- still be read. Written inside the same transaction as the change it records.
--
-- Covered: request approve / reject / delete (admin override), PTO days and
-- call-ins added or removed on the schedule page, attendance points, performance
-- notes and errors. Read by Supervisors and Super Admins only (Change log button
-- on the PTO calendar and the Employee Overview). The API has no update or delete
-- for this table.
--
-- Actor and employee are stored by id AND by name: the name is a snapshot, so a
-- renamed or deleted account cannot blur who did what. The FKs SET NULL rather
-- than CASCADE for the same reason — history outlives the people in it.
--
-- Additive and idempotent; multi-team safe. Safe to re-run.

CREATE TABLE IF NOT EXISTS audit_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  team_id uuid,
  actor_id uuid,
  actor_name text NOT NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  employee_id uuid,
  employee_name text,
  summary text NOT NULL,
  before jsonb,
  after jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT audit_log_pkey PRIMARY KEY (id),
  CONSTRAINT audit_log_team_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  CONSTRAINT audit_log_actor_fkey FOREIGN KEY (actor_id) REFERENCES user_profiles(id) ON DELETE SET NULL,
  CONSTRAINT audit_log_employee_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL,
  CONSTRAINT check_audit_log_action CHECK (action IN ('approve', 'reject', 'delete', 'add', 'edit')),
  CONSTRAINT check_audit_log_entity CHECK (entity_type IN ('request', 'pto_day', 'attendance_point', 'performance_note', 'performance_error'))
);

CREATE INDEX IF NOT EXISTS idx_audit_log_team_time     ON audit_log (team_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_employee_time ON audit_log (employee_id, created_at DESC);
