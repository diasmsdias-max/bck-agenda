BEGIN;

ALTER TABLE appointment
    ADD COLUMN IF NOT EXISTS arrived_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS service_started_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS service_finished_at timestamptz NULL;

ALTER TABLE appointment
    DROP CONSTRAINT IF EXISTS appointment_actual_timing_check;

ALTER TABLE appointment
    ADD CONSTRAINT appointment_actual_timing_check CHECK (
        (service_started_at IS NULL OR service_finished_at IS NULL OR service_finished_at >= service_started_at)
        AND (arrived_at IS NULL OR service_started_at IS NULL OR service_started_at >= arrived_at)
    );

CREATE INDEX IF NOT EXISTS ix_appointment_group_actual_timing
    ON appointment(group_id, professional_user_id, service_started_at, service_finished_at)
    WHERE service_started_at IS NOT NULL;

COMMIT;
