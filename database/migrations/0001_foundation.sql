BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE bck_group (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    tax_id text NULL,
    phone text NULL,
    timezone text NOT NULL DEFAULT 'America/Sao_Paulo',
    status text NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE bck_user (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    name text NOT NULL,
    phone text NULL,
    function_name text NULL,
    profile text NOT NULL CHECK (profile IN ('ADMIN','USER')),
    is_owner boolean NOT NULL DEFAULT false,
    serves_clients boolean NOT NULL DEFAULT true,
    password_hash text NOT NULL,
    active boolean NOT NULL DEFAULT true,
    permission_version integer NOT NULL DEFAULT 1,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bck_group ADD COLUMN owner_user_id uuid NULL REFERENCES bck_user(id);

CREATE TABLE permission (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    description text NOT NULL
);

CREATE TABLE user_permission (
    user_id uuid NOT NULL REFERENCES bck_user(id) ON DELETE CASCADE,
    permission_id uuid NOT NULL REFERENCES permission(id) ON DELETE CASCADE,
    granted boolean NOT NULL DEFAULT true,
    PRIMARY KEY (user_id, permission_id)
);

CREATE TABLE device (
    id uuid PRIMARY KEY,
    group_id uuid NOT NULL REFERENCES bck_group(id),
    name text NOT NULL,
    platform text NOT NULL,
    device_mode text NOT NULL CHECK (device_mode IN ('PERSONAL','SHARED')),
    is_principal boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'ACTIVE',
    security_version integer NOT NULL DEFAULT 1,
    last_validated_at timestamptz NULL,
    revoked_at timestamptz NULL,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE device_user (
    device_id uuid NOT NULL REFERENCES device(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES bck_user(id) ON DELETE CASCADE,
    quick_access_enabled boolean NOT NULL DEFAULT false,
    last_login_at timestamptz NULL,
    PRIMARY KEY (device_id, user_id)
);

CREATE TABLE audit_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    user_id uuid NULL REFERENCES bck_user(id),
    device_id uuid NULL REFERENCES device(id),
    action text NOT NULL,
    entity_type text NULL,
    entity_id uuid NULL,
    before_json jsonb NULL,
    after_json jsonb NULL,
    metadata_json jsonb NULL,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    server_received_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sync_event (
    event_id uuid PRIMARY KEY,
    group_id uuid NOT NULL REFERENCES bck_group(id),
    device_id uuid NOT NULL REFERENCES device(id),
    user_id uuid NULL REFERENCES bck_user(id),
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    operation text NOT NULL,
    payload jsonb NOT NULL,
    base_version integer NULL,
    occurred_at timestamptz NOT NULL,
    idempotency_key text NOT NULL UNIQUE,
    sync_status text NOT NULL DEFAULT 'ACCEPTED',
    server_received_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO permission (code, description) VALUES
('ALLOW_FIT_IN', 'Permitir encaixe na própria agenda'),
('ALLOW_DISCOUNT', 'Permitir desconto ou alteração de preço')
ON CONFLICT (code) DO NOTHING;

CREATE INDEX ix_user_group_active ON bck_user(group_id, active);
CREATE INDEX ix_device_group_status ON device(group_id, status);
CREATE INDEX ix_audit_group_time ON audit_log(group_id, occurred_at DESC);
CREATE INDEX ix_sync_group_received ON sync_event(group_id, server_received_at);

COMMIT;
