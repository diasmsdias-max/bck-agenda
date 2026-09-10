BEGIN;

CREATE TABLE client (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    name text NOT NULL,
    phone text NOT NULL,
    whatsapp_enabled boolean NOT NULL DEFAULT true,
    notes text NULL,
    birth_date date NULL,
    active boolean NOT NULL DEFAULT true,
    version integer NOT NULL DEFAULT 1,
    created_by_user_id uuid NULL REFERENCES bck_user(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_client_group_name ON client(group_id, lower(name));
CREATE INDEX ix_client_group_phone ON client(group_id, phone);

CREATE TABLE service (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    name text NOT NULL,
    description text NULL,
    standard_price numeric(14,2) NOT NULL DEFAULT 0 CHECK (standard_price >= 0),
    standard_duration_minutes integer NOT NULL CHECK (standard_duration_minutes > 0),
    active boolean NOT NULL DEFAULT true,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_service_group_active_name ON service(group_id, active, lower(name));

CREATE TABLE appointment (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    client_id uuid NULL REFERENCES client(id),
    walk_in_name text NULL,
    walk_in_phone text NULL,
    professional_user_id uuid NOT NULL REFERENCES bck_user(id),
    created_by_user_id uuid NOT NULL REFERENCES bck_user(id),
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    status text NOT NULL DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED','CONFIRMED','WAITING','IN_SERVICE','COMPLETED','CANCELLED','NO_SHOW','RESCHEDULED')),
    notes text NULL,
    is_fit_in boolean NOT NULL DEFAULT false,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_at > starts_at),
    CHECK (client_id IS NOT NULL OR walk_in_name IS NOT NULL)
);

CREATE INDEX ix_appointment_group_professional_time ON appointment(group_id, professional_user_id, starts_at, ends_at);
CREATE INDEX ix_appointment_group_client_time ON appointment(group_id, client_id, starts_at DESC) WHERE client_id IS NOT NULL;

CREATE TABLE appointment_service (
    appointment_id uuid NOT NULL REFERENCES appointment(id) ON DELETE CASCADE,
    service_id uuid NOT NULL REFERENCES service(id),
    sequence integer NOT NULL DEFAULT 1,
    price_snapshot numeric(14,2) NOT NULL CHECK (price_snapshot >= 0),
    duration_minutes_snapshot integer NOT NULL CHECK (duration_minutes_snapshot > 0),
    PRIMARY KEY (appointment_id, service_id, sequence)
);

CREATE TABLE appointment_status_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    appointment_id uuid NOT NULL REFERENCES appointment(id) ON DELETE CASCADE,
    from_status text NULL,
    to_status text NOT NULL,
    changed_by_user_id uuid NOT NULL REFERENCES bck_user(id),
    reason text NULL,
    changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_appointment_status_history_appointment ON appointment_status_history(appointment_id, changed_at);

COMMIT;
