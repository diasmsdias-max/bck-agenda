# BCK Agenda — servidor local para Alpha

Este ambiente sobe o PostgreSQL em Docker, aplica todas as migrations versionadas e inicia a API BCK na porta 5080.

## Pré-requisitos no Windows

- Docker Desktop com Docker Compose.
- .NET 10 SDK.
- Repositório `bck-agenda` disponível no computador servidor.

## Iniciar

Abra PowerShell na raiz do repositório e execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\test-server\start-bck-alpha.ps1
```

Na primeira execução o script cria `infra/test-server/.env.local` com senha PostgreSQL e chave JWT aleatórias. Esse arquivo é ignorado pelo Git e não deve ser compartilhado.

Teste local:

```powershell
Invoke-RestMethod http://127.0.0.1:5080/api/v1/health
```

A API escuta em `0.0.0.0:5080`, mas o PostgreSQL fica publicado apenas em `127.0.0.1:5432`; o banco não deve ser exposto à Internet.

## Celular na mesma rede

Para um teste temporário na mesma rede Wi-Fi, descubra o IPv4 do computador com `ipconfig`, libere somente a porta TCP 5080 no Firewall do Windows para a rede privada e gere o APK com:

```text
--dart-define=BCK_API_URL=http://IP_DO_SERVIDOR:5080
```

Para teste externo/Internet, não publique a porta 5080 diretamente no roteador. Use um túnel HTTPS e gere o APK apontando `BCK_API_URL` para a URL HTTPS do túnel.

## Encerrar

Feche a API com Ctrl+C. Para parar o PostgreSQL:

```powershell
docker compose --env-file .\infra\test-server\.env.local -f .\infra\test-server\docker-compose.yml down
```

O volume `bck_alpha_pgdata` preserva os dados entre reinicializações.
