-- EP04 - Clientes
-- Protege concorrencia de cadastro/sincronizacao sem misturar tenants.
-- A chave considera somente digitos e permanece isolada por group_id.

CREATE UNIQUE INDEX IF NOT EXISTS ux_client_group_phone_normalized
ON client (group_id, regexp_replace(phone, '[^0-9]', '', 'g'))
WHERE length(regexp_replace(phone, '[^0-9]', '', 'g')) >= 8;
