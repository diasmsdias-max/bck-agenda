BEGIN;

-- Nome canônico usado pela API/Flutter para desconto ou alteração de preço.
INSERT INTO permission (code, description)
VALUES ('ALLOW_PRICE_OVERRIDE', 'Permitir desconto ou alteração de preço')
ON CONFLICT (code) DO NOTHING;

-- Preserva concessões criadas com o código legado da fundação.
INSERT INTO user_permission (user_id, permission_id, granted)
SELECT up.user_id, canonical.id, up.granted
FROM user_permission up
JOIN permission legacy ON legacy.id = up.permission_id AND legacy.code = 'ALLOW_DISCOUNT'
JOIN permission canonical ON canonical.code = 'ALLOW_PRICE_OVERRIDE'
ON CONFLICT (user_id, permission_id) DO UPDATE SET granted = EXCLUDED.granted;

-- Login deve permanecer único dentro da empresa mesmo quando um usuário é inativado.
-- Isso evita reativação/duplicidade ambígua de credenciais.
DROP INDEX IF EXISTS ux_bck_user_group_username;
CREATE UNIQUE INDEX ux_bck_user_group_username
    ON bck_user(group_id, lower(username))
    WHERE username IS NOT NULL;

COMMIT;
