# EP03 — Usuários e Aparelhos

## Incremento 1 — gestão administrativa de aparelhos

Endpoints autenticados e restritos a Administrador:

- `GET /api/v1/devices` — lista somente aparelhos da empresa autenticada.
- `PATCH /api/v1/devices/{deviceId}/mode` — alterna `PERSONAL`/`SHARED`, incrementa `security_version` e desativa acesso rápido local vinculado ao aparelho.
- `POST /api/v1/devices/{deviceId}/revoke` — revoga aparelho não principal e incrementa `security_version`.

Regras:

- O `group_id` é sempre derivado do JWT.
- Um administrador não pode consultar ou alterar aparelho de outra empresa.
- Mudança de modo invalida a sessão online anterior via `security_version`.
- Toda mudança de modo desabilita `quick_access_enabled`; o usuário precisa habilitar novamente quando o modo permitir.
- O aparelho principal não pode ser revogado por este endpoint para evitar bloqueio administrativo acidental.
- Revogação e mudança de modo geram eventos no `audit_log`.

Próximo incremento da EP03: integrar a listagem e ações à tela Flutter `Dispositivos`, seguido da gestão de usuários e permissões.
