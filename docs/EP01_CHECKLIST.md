# EP01 — Fundação

## Concluído no repositório
- [x] Branch `ep01-foundation`.
- [x] Stack e arquitetura base definidos.
- [x] `.gitignore` e template de ambiente.
- [x] PostgreSQL de desenvolvimento via Docker Compose.
- [x] Migration 0001 com grupo, usuário, permissões, dispositivos, auditoria e eventos de sincronização.
- [x] Projeto inicial ASP.NET Core.
- [x] Endpoint `GET /api/v1/health`.

## Próxima execução
- [ ] Validar build com .NET 10 SDK.
- [ ] Aplicar migration em PostgreSQL vazio.
- [ ] Criar testes de integração da API.
- [ ] Criar projeto Flutter Android/Windows/iOS.
- [ ] Configurar SQLite local.
- [ ] Cliente Flutter consultar `/api/v1/health`.
- [ ] Pipeline CI executar API e Flutter.

## Critério de saída
Um Android recém-instalado inicializa seu banco local, consulta a API BCK e recebe `status=ok`, com testes automatizados verdes.
