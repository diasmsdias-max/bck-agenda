-- EP07 gate: regras críticas do atendimento permanecem no contrato de persistência.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='service_session'
           AND column_name='client_name_snapshot'
    ) THEN
        RAISE EXCEPTION 'EP07 client snapshot is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='service_session_item'
           AND column_name='unit_price_snapshot'
    ) THEN
        RAISE EXCEPTION 'EP07 price snapshot is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid='service_session'::regclass
           AND pg_get_constraintdef(oid) LIKE '%total = (subtotal - discount_total)%'
    ) THEN
        RAISE EXCEPTION 'EP07 consolidated total invariant is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid='service_session_item'::regclass
           AND pg_get_constraintdef(oid) LIKE '%line_total = (line_subtotal - discount_amount)%'
    ) THEN
        RAISE EXCEPTION 'EP07 line total invariant is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
         WHERE schemaname='public' AND tablename='service_session'
           AND indexdef LIKE '%appointment_id%'
           AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'EP07 appointment/session uniqueness is missing';
    END IF;
END;
$$;
