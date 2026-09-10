# EP03 — Usuários e Aparelhos

## Objetivo

Entregar a administração de usuários e aparelhos da Empresa/Grupo BCK, preservando isolamento multi-tenant, proteção do Proprietário e invalidação de sessões quando permissões ou segurança mudarem.

## Aparelhos

Endpoints autenticados e restritos a Administrador:

- `GET /api/v1/devices` — lista somente aparelhos da empresa autenticada.
- `POST /api/v1/devices/pair` — gera código temporário de conexão para aparelho Pessoal ou Compartilhado.
- `PATCH /api/v1/devices/{deviceId}/mode` — alterna `PERSONAL`/`SHARED`, incrementa `security_version` e desativa acesso rápido local vinculado ao aparelho.
- `POST /api/v1/devices/{deviceId}/revoke` — revoga aparelho não principal e incrementa `security_version`.

Regras:

- `group_id` é sempre derivado da identidade autenticada/JWT.
- Administrador não consulta nem altera aparelho de outra empresa.
- Mudança de modo invalida sessão online anterior via `security_version` quando aplicável.
- Mudança de modo desabilita `quick_access_enabled`; credenciais rápidas devem ser habilitadas novamente quando o modo permitir.
- Aparelho Compartilhado não utiliza acesso rápido; cada usuário autentica com usuário e senha.
- Aparelho Pessoal exige vínculo do usuário ao aparelho para autenticação.
- Aparelho principal não pode ser revogado pelo endpoint administrativo comum.
- Revogação e mudança de modo geram auditoria.
- Código de pairing expirado não autoriza aparelho.
- Pairing não pode reutilizar/sequestrar `deviceId` pertencente a outra empresa.

## Usuários

Endpoints autenticados e restritos a Administrador:

- `GET /api/v1/users` — lista usuários da empresa autenticada.
- `POST /api/v1/users` — cria usuário na empresa autenticada.
- `PUT /api/v1/users/{id}` — atualiza cadastro, perfil, estado e permissões.
- `POST /api/v1/users/{id}/reset-password` — redefine senha administrativa sem expor senha anterior.

Campos funcionais deste incremento:

- Nome;
- Telefone;
- Função;
- Perfil `ADMIN` ou `USER`;
- indicador `Atende clientes`;
- ativo/inativo;
- usuário de login;
- senha somente na criação/redefinição;
- permissões especiais `ALLOW_FIT_IN` e `ALLOW_PRICE_OVERRIDE`.

Regras:

- Proprietário permanece Administrador e ativo.
- Senhas nunca são retornadas pela API.
- Usuário comum recebe `403` nas rotas administrativas de usuários e pairing.
- Empresa B não lista nem altera usuário da Empresa A.
- Mudanças relevantes de usuário incrementam `permission_version`, invalidando tokens antigos.
- Redefinição de senha invalida sessões antigas.
- Alteração cadastral protegida do Proprietário não invalida desnecessariamente a própria sessão quando perfil/estado solicitados são recusados.
- Operações administrativas são registradas no `audit_log`.

## Flutter

- `Mais → Dispositivos`: lista aparelhos, mostra modo, status, principal, último acesso e usuários vinculados; permite gerar pairing, alterar Pessoal/Compartilhado e revogar aparelho não principal.
- `Mais → Usuários`: lista equipe, identifica Proprietário, perfil, função e estado; permite cadastrar/editar, configurar `Atende clientes`, permissões especiais, ativar/inativar e redefinir senha.
- As áreas administrativas são exibidas somente para perfil Administrador.

## Segurança automatizada

O workflow `BCK Shared Device Security` cobre, entre outros:

- isolamento Empresa A × Empresa B;
- autenticação Pessoal × Compartilhado;
- usuário comum impedido de administrar equipe e pairing;
- proteção do Proprietário;
- invalidação de token após mudança de permissões;
- bloqueio de credenciais cruzadas entre empresas;
- bloqueio de sequestro de `deviceId` no pairing;
- expiração de código de pairing.

## Estado da EP03

Implementação funcional concluída e em revisão final no PR #3. Gates registrados na revisão final: `BCK Agenda CI #107` e `BCK Shared Device Security #28`, ambos com sucesso. O PR deve permanecer sem merge até autorização explícita.
