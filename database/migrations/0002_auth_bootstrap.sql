BEGIN;

ALTER TABLE bck_user
    ADD COLUMN username text NULL,
    ADD COLUMN must_change_password boolean NOT NULL DEFAULT false,
    ADD COLUMN last_login_at timestamptz NULL;

CREATE UNIQUE INDEX ux_bck_user_group_username
    ON bck_user(group_id, lower(username))
    WHERE username IS NOT NULL AND active = true;

CREATE TABLE refresh_token (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    user_id uuid NOT NULL REFERENCES bck_user(id),
    device_id uuid NOT NULL REFERENCES device(id),
    token_hash text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz NULL,
    replaced_by_token_id uuid NULL REFERENCES refresh_token(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    last_used_at timestamptz NULL
);

CREATE INDEX ix_refresh_token_user_device
    ON refresh_token(group_id, user_id, device_id, expires_at DESC);

CREATE TABLE device_pairing_token (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    created_by_user_id uuid NOT NULL REFERENCES bck_user(id),
    token_hash text NOT NULL UNIQUE,
    requested_device_mode text NOT NULL CHECK (requested_device_mode IN ('PERSONAL','SHARED')),
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_device_pairing_group_expiry
    ON device_pairing_token(group_id, expires_at DESC);

COMMIT;
