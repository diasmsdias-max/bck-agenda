-- EP04 integration contract: tenant isolation and normalized phone uniqueness.
-- Executar após todas as migrations em um banco de teste vazio.

BEGIN;

DO $$
DECLARE
  group_a uuid := gen_random_uuid();
  group_b uuid := gen_random_uuid();
  client_a uuid;
  client_b uuid;
BEGIN
  INSERT INTO bck_group(id, name) VALUES
    (group_a, 'EP04 Tenant A'),
    (group_b, 'EP04 Tenant B');

  INSERT INTO client(group_id, name, phone)
  VALUES (group_a, 'Cliente A', '(27) 99999-0001')
  RETURNING id INTO client_a;

  -- O mesmo telefone normalizado é válido em outro tenant.
  INSERT INTO client(group_id, name, phone)
  VALUES (group_b, 'Cliente B', '27 99999-0001')
  RETURNING id INTO client_b;

  IF NOT EXISTS (SELECT 1 FROM client WHERE id=client_a AND group_id=group_a) THEN
    RAISE EXCEPTION 'Cliente A não encontrado no próprio tenant';
  END IF;

  IF EXISTS (SELECT 1 FROM client WHERE id=client_a AND group_id=group_b) THEN
    RAISE EXCEPTION 'Falha de isolamento: tenant B enxergou cliente A';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM client WHERE id=client_b AND group_id=group_b) THEN
    RAISE EXCEPTION 'Cliente B não encontrado no próprio tenant';
  END IF;

  -- Dentro do mesmo tenant, outra formatação do mesmo telefone deve violar o índice único.
  BEGIN
    INSERT INTO client(group_id, name, phone)
    VALUES (group_a, 'Duplicado A', '27.99999.0001');
    RAISE EXCEPTION 'Telefone duplicado foi aceito no mesmo tenant';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;
END $$;

ROLLBACK;
