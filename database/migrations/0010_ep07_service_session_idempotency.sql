BEGIN;

CREATE TABLE service_session_idempotency (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    user_id uuid NOT NULL REFERENCES bck_user(id),
    operation text NOT NULL CHECK (operation IN ('OPEN','ADD_ITEM','FINISH')),
    idempotency_key text NOT NULL,
    request_hash text NOT NULL,
    status_code integer NULL,
    response_json jsonb NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz NULL,
    UNIQUE (group_id, user_id, operation, idempotency_key),
    CHECK (length(idempotency_key) BETWEEN 8 AND 128),
    CHECK (length(request_hash) = 64),
    CHECK ((status_code IS NULL AND response_json IS NULL AND completed_at IS NULL)
        OR (status_code IS NOT NULL AND response_json IS NOT NULL AND completed_at IS NOT NULL))
);

CREATE INDEX ix_service_session_idempotency_created_at
    ON service_session_idempotency(created_at);

COMMIT;
