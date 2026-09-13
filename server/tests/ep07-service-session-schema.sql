-- EP07 gate: atendimento possui vínculo obrigatório com agenda/profissional,
-- snapshots comerciais, itens auditáveis e total consolidado.
DO $$
BEGIN
    IF to_regclass('public.service_session') IS NULL THEN
        RAISE EXCEPTION 'EP07 service_session table is missing';
    END IF;

    IF to_regclass('public.service_session_item') IS NULL THEN
        RAISE EXCEPTION 'EP07 service_session_item table is missing';
    END IF;

    IF to_regclass('public.service_session_history') IS NULL THEN
        RAISE EXCEPTION 'EP07 service_session_history table is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'service_session'::regclass
           AND contype = 'u'
           AND pg_get_constraintdef(oid) LIKE '%appointment_id%'
    ) THEN
        RAISE EXCEPTION 'EP07 appointment must map to a single service session';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = 'service_session_item'
           AND column_name = 'unit_price_snapshot'
    ) THEN
        RAISE EXCEPTION 'EP07 item price snapshot is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = 'service_session'
           AND column_name = 'total'
    ) THEN
        RAISE EXCEPTION 'EP07 consolidated total is missing';
    END IF;
END;
$$;
