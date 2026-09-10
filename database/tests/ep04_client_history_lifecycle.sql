BEGIN;
DO $$
DECLARE
  g uuid := gen_random_uuid();
  u uuid := gen_random_uuid();
  c uuid;
  v integer;
BEGIN
  INSERT INTO bck_group(id,name) VALUES(g,'EP04 History Lifecycle');
  INSERT INTO bck_user(id,group_id,name,profile,is_owner,serves_clients,password_hash,username)
  VALUES(u,g,'Admin','ADMIN',true,true,'test','ep04-history');
  INSERT INTO client(group_id,name,phone,created_by_user_id)
  VALUES(g,'Cliente com histórico','27999990401',u) RETURNING id,version INTO c,v;
  INSERT INTO appointment(group_id,client_id,professional_user_id,created_by_user_id,starts_at,ends_at,status)
  VALUES(g,c,u,u,now(),now()+interval '30 minutes','SCHEDULED');

  UPDATE client SET active=false,version=version+1,updated_at=now()
  WHERE id=c AND group_id=g;
  IF NOT EXISTS(SELECT 1 FROM client WHERE id=c AND active=false AND version=v+1) THEN
    RAISE EXCEPTION 'Inativação/versionamento falhou';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM appointment WHERE group_id=g AND client_id=c) THEN
    RAISE EXCEPTION 'Histórico foi perdido';
  END IF;

  UPDATE client SET active=true,version=version+1,updated_at=now()
  WHERE id=c AND group_id=g AND active=false;
  IF NOT EXISTS(SELECT 1 FROM client WHERE id=c AND active=true AND version=v+2) THEN
    RAISE EXCEPTION 'Reativação/versionamento falhou';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM appointment WHERE group_id=g AND client_id=c) THEN
    RAISE EXCEPTION 'Histórico foi perdido após reativação';
  END IF;
END $$;
ROLLBACK;
