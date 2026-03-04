CREATE TABLE IF NOT EXISTS pm_step_events (
  id BIGSERIAL PRIMARY KEY,
  event_id TEXT NOT NULL UNIQUE,
  workflow_run_id TEXT NOT NULL,
  task_id TEXT,
  step_id TEXT NOT NULL,
  parent_step_id TEXT,
  phase TEXT,
  step_name TEXT,
  event_type TEXT NOT NULL,
  agent_role TEXT,
  invoked_by_role TEXT,
  runtime TEXT,
  provider TEXT,
  model TEXT,
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  duration_ms BIGINT,
  prompt_tokens INTEGER,
  completion_tokens INTEGER,
  total_tokens INTEGER,
  usage_source TEXT NOT NULL DEFAULT 'provider_response',
  usage_status TEXT NOT NULL DEFAULT 'complete',
  status TEXT,
  error_or_warning_code TEXT,
  warning_message TEXT,
  remediation TEXT,
  request_id TEXT,
  trace_id TEXT,
  span_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (duration_ms IS NULL OR duration_ms >= 0),
  CHECK (prompt_tokens IS NULL OR prompt_tokens >= 0),
  CHECK (completion_tokens IS NULL OR completion_tokens >= 0),
  CHECK (total_tokens IS NULL OR total_tokens >= 0)
);

CREATE INDEX IF NOT EXISTS idx_pm_step_events_task_created
  ON pm_step_events (task_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_pm_step_events_run_created
  ON pm_step_events (workflow_run_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_pm_step_events_phase_step
  ON pm_step_events (phase, step_name, created_at DESC);
