-- EP04: prova de persistência para concorrência, exclusão, inativação e reativação.
BEGIN;
DO $$
DECLARE
  g uuid := gen_random_uuid();
  u uuid := gen_random_uuid();
  c_free uuid;
  c_history uuid;
  v integer;
BEGIN
  INSERT INTO bck_group(id,name) VALUES(g,'EP04 Lifecycle');
  INSERT INTO bck_user(id,group_id,name,profile,is_owner,serves_clients,password_hash,username)
  VALUES(u,g,'Admin','ADMIN',true,true,'test','ep04-lifecycle');

  INSERT INTO client(group_id,name,phone,created_by_user_id)
  VALUES(g,'Sem histórico','27999990301',u) RETURNING id,version INTO c_free,v;

  UPDATE client SET name='Versão nova',version=version+1,updated_at=now()
  WHERE id=c_free AND group_id=g AND version=v;
  IF NOT FOUND THEN RAISE EXCEPTION 'Atualização com versão corrente falhou'; END IF;

  UPDATE client SET name='Sobrescrita inválida',version=version+1,updated_at=now()
  WHERE id=c_free AND group_id=g AND version=v;
  IF FOUND THEN RAISE EXCEPTION 'Versão antiga sobrescreveu registro mais novo'; END IF;

  DELETE FROM client WHERE id=c_free AND group_id=g;
  IF EXISTS(SELECT 1 FROM client WHERE id=c_free) THEN
    RAISE EXCEPTION 'Cliente sem histórico deveria ser removível';
  END IF;

  INSERT INTO client(group_id,name,phone,created_by_user_id)
  VALUES(g,'Com histórico','27999990302',u) RETURNING id INTO c_history;
  INSERT INTO appointment(group_id,client_id,professional_user_id,created_by_user_id,starts_at,ends_at,status)
  VALUES(g,c_history,u,u,now(),now()+interval '30 minutes','SCHEDULED');

  UPDATE client SET active=false,version=version+1,updated_at=now()
  WHERE id=c_history AND group_id=g;
  IF NOT EXISTS(SELECT 1 FROM client WHERE id=c_history AND group_id=g AND active=false) THEN
    RAISE EXCEPTION 'Cliente com histórico deve permanecer inativo';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM appointment WHERE client_id=c_history AND group_id=g) THEN
    RAISE EXCEPTION 'Histórico do cliente foi perdido';
  END IF;

  UPDATE client SET active=true,version=version+1,updated_at=now()
  WHERE id=c_history AND group_id=g AND active=false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Reativação do cliente inativo falhou'; END IF;
  IF NOT EXISTS(SELECT 1 FROM client WHERE id=c_history AND group_id=g AND active=true) THEN
    RAISE EXCEPTION 'Reativação não persistiu';
  END IF;
END $$;
ROLLBACK;
