-- Fixture helper for EP04 HTTP lifecycle tests.
-- Usage: psql -v group_id=... -v client_id=... -v user_id=...
INSERT INTO service(group_id,name,standard_price,standard_duration_minutes)
VALUES (:'group_id'::uuid,'EP04 HTTP fixture',50,30)
RETURNING id;
