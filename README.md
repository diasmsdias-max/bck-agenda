# BCK Agenda

Sistema de agenda e gestão para negócios de atendimento, com operação offline-first.

## Arquitetura V1

- Flutter/Dart: Android primeiro, Windows preparado e iOS futuro.
- API BCK em ASP.NET Core/C#.
- PostgreSQL como banco central.
- SQLite local no aplicativo para operação offline.
- API como única camada de acesso ao banco central.
- Sincronização incremental, idempotência, auditoria e isolamento por empresa/grupo.

## Status

EP01 — Fundação em desenvolvimento.

A primeira meta executável é: PostgreSQL + migration inicial + API `/health` + cliente Flutter consultando a API.
