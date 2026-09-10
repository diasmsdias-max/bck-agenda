# BCK Agenda database migrations

Os arquivos SQL desta pasta são a fonte canônica do schema PostgreSQL.

Regras:

1. Migrations já publicadas não devem ser reescritas após entrar em produção.
2. Novas mudanças usam novos arquivos sequenciais (`0002_...sql`, `0003_...sql`).
3. Toda migration deve falhar imediatamente em erro e executar dentro de transação quando possível.
4. O endpoint `/api/v1/health/database` verifica a conexão e a presença da fundação.
5. Em desenvolvimento, `database/apply-migrations.sh` pode aplicar a sequência usando `BCK_POSTGRES_CONNECTION`.

O modelo de dispositivo separa `device_mode` (`PERSONAL`/`SHARED`) de `is_principal`, pois um aparelho principal continua tendo um modo de autenticação próprio.
