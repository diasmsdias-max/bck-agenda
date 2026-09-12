-- EP06 gate: real service timing is captured by status transitions.
-- This script is intentionally schema-level so it can run against the same
-- PostgreSQL migration chain used by the API integration gates.
DO $$
DECLARE
    fn_definition text;
BEGIN
    SELECT pg_get_functiondef(p.oid)
      INTO fn_definition
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE p.proname = 'bck_capture_appointment_actual_timing'
     LIMIT 1;

    IF fn_definition IS NULL THEN
        RAISE EXCEPTION 'EP06 timing function is missing';
    END IF;

    IF position('arrived_at' in fn_definition) = 0
       OR position('service_started_at' in fn_definition) = 0
       OR position('service_finished_at' in fn_definition) = 0 THEN
        RAISE EXCEPTION 'EP06 timing function does not cover the full lifecycle';
    END IF;

    IF position('IF NEW.status = ''IN_SERVICE'' THEN' in fn_definition) = 0
       OR position('NEW.arrived_at := now()' in fn_definition) = 0 THEN
        RAISE EXCEPTION 'EP06 direct IN_SERVICE transition must capture arrival';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgname = 'trg_appointment_actual_timing'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'EP06 timing trigger is missing';
    END IF;
END;
$$;
