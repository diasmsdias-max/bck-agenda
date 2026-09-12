BEGIN;

CREATE TABLE service_session (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    appointment_id uuid NOT NULL REFERENCES appointment(id),
    client_id uuid NULL REFERENCES client(id),
    client_name_snapshot text NOT NULL,
    client_phone_snapshot text NULL,
    professional_user_id uuid NOT NULL REFERENCES bck_user(id),
    opened_by_user_id uuid NOT NULL REFERENCES bck_user(id),
    finished_by_user_id uuid NULL REFERENCES bck_user(id),
    status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','IN_SERVICE','FINISHED','CANCELLED')),
    notes text NULL,
    subtotal numeric(14,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    discount_total numeric(14,2) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
    total numeric(14,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz NULL,
    UNIQUE (appointment_id),
    CHECK (discount_total <= subtotal),
    CHECK (total = subtotal - discount_total)
);

CREATE INDEX ix_service_session_group_status
    ON service_session(group_id, status, updated_at DESC);
CREATE INDEX ix_service_session_group_professional
    ON service_session(group_id, professional_user_id, created_at DESC);
CREATE INDEX ix_service_session_group_client
    ON service_session(group_id, client_id, created_at DESC)
    WHERE client_id IS NOT NULL;

CREATE TABLE service_session_item (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    service_session_id uuid NOT NULL REFERENCES service_session(id) ON DELETE CASCADE,
    item_type text NOT NULL CHECK (item_type IN ('SERVICE','PRODUCT')),
    service_id uuid NULL REFERENCES service(id),
    source_item_id uuid NULL,
    name_snapshot text NOT NULL,
    quantity numeric(12,3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price_snapshot numeric(14,2) NOT NULL CHECK (unit_price_snapshot >= 0),
    discount_amount numeric(14,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    line_subtotal numeric(14,2) NOT NULL CHECK (line_subtotal >= 0),
    line_total numeric(14,2) NOT NULL CHECK (line_total >= 0),
    added_by_user_id uuid NOT NULL REFERENCES bck_user(id),
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (discount_amount <= line_subtotal),
    CHECK (line_total = line_subtotal - discount_amount),
    CHECK ((item_type = 'SERVICE' AND service_id IS NOT NULL) OR item_type = 'PRODUCT')
);

CREATE INDEX ix_service_session_item_session
    ON service_session_item(service_session_id, created_at, id);
CREATE INDEX ix_service_session_item_group_source
    ON service_session_item(group_id, source_item_id)
    WHERE source_item_id IS NOT NULL;

CREATE TABLE service_session_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES bck_group(id),
    service_session_id uuid NOT NULL REFERENCES service_session(id) ON DELETE CASCADE,
    changed_by_user_id uuid NOT NULL REFERENCES bck_user(id),
    action text NOT NULL,
    before_json jsonb NULL,
    after_json jsonb NULL,
    changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_service_session_history_session
    ON service_session_history(service_session_id, changed_at, id);

COMMIT;
