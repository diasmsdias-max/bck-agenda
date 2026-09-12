\set ON_ERROR_STOP on

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM permission WHERE code = 'ALLOW_PRICE_OVERRIDE'
  ) THEN
    RAISE EXCEPTION 'EP07 requires canonical ALLOW_PRICE_OVERRIDE permission';
  END IF;

  IF EXISTS (
    SELECT 1 FROM permission WHERE code = 'ALLOW_PRICE_CHANGE'
  ) THEN
    RAISE EXCEPTION 'Legacy/invalid ALLOW_PRICE_CHANGE must not be used by EP07';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = current_schema()
      AND tablename = 'service_session'
      AND indexname = 'ix_service_session_group_professional'
  ) THEN
    RAISE EXCEPTION 'service_session must keep group/professional scoped index';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_schema = current_schema()
      AND table_name = 'service_session'
      AND constraint_type = 'UNIQUE'
  ) THEN
    RAISE EXCEPTION 'service_session must preserve unique appointment relationship';
  END IF;
END $$;

-- Every mutable EP07 aggregate carries group_id explicitly so API queries can
-- enforce tenant scope even when identifiers are known by another tenant.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['service_session','service_session_item','service_session_history'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = current_schema() AND table_name = t AND column_name = 'group_id'
    ) THEN
      RAISE EXCEPTION '% must carry group_id for tenant isolation', t;
    END IF;
  END LOOP;
END $$;
