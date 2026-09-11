$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '../..')
$Compose = Join-Path $PSScriptRoot 'docker-compose.yml'
$EnvFile = Join-Path $PSScriptRoot '.env.local'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw 'Docker não encontrado. Instale o Docker Desktop e execute novamente.'
}
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
  throw '.NET SDK não encontrado. Instale o .NET 10 SDK e execute novamente.'
}
if (-not (Test-Path $EnvFile)) {
  $password = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 })) -replace '[^a-zA-Z0-9]', ''
  $jwt = [Convert]::ToBase64String((1..48 | ForEach-Object { Get-Random -Maximum 256 }))
  @"
POSTGRES_DB=bck_agenda
POSTGRES_USER=bck
POSTGRES_PASSWORD=$password
BCK_JWT_SIGNING_KEY=$jwt
"@ | Set-Content -Encoding UTF8 $EnvFile
  Write-Host 'Configuração local segura criada em infra/test-server/.env.local.'
}

Get-Content $EnvFile | ForEach-Object {
  if ($_ -match '^([^#=]+)=(.*)$') { Set-Item -Path "Env:$($matches[1])" -Value $matches[2] }
}

docker compose --env-file $EnvFile -f $Compose up -d

Write-Host 'Aguardando PostgreSQL...'
for ($i=0; $i -lt 30; $i++) {
  $ready = docker compose --env-file $EnvFile -f $Compose exec -T postgres pg_isready -U $env:POSTGRES_USER -d $env:POSTGRES_DB 2>$null
  if ($LASTEXITCODE -eq 0) { break }
  Start-Sleep -Seconds 2
}
if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL não ficou pronto no tempo esperado.' }

$migrations = Get-ChildItem (Join-Path $Root 'database/migrations/*.sql') | Sort-Object Name
foreach ($migration in $migrations) {
  Write-Host "Aplicando $($migration.Name)..."
  Get-Content -Raw $migration.FullName | docker compose --env-file $EnvFile -f $Compose exec -T postgres psql -v ON_ERROR_STOP=1 -U $env:POSTGRES_USER -d $env:POSTGRES_DB
  if ($LASTEXITCODE -ne 0) { throw "Falha na migration $($migration.Name)." }
}

$env:BCK_POSTGRES_CONNECTION = "Host=127.0.0.1;Port=5432;Database=$($env:POSTGRES_DB);Username=$($env:POSTGRES_USER);Password=$($env:POSTGRES_PASSWORD)"
$env:ASPNETCORE_URLS = 'http://0.0.0.0:5080'

Write-Host ''
Write-Host 'BCK Alpha Server iniciando em http://0.0.0.0:5080'
Write-Host 'Health local: http://127.0.0.1:5080/api/v1/health'
Write-Host 'Mantenha esta janela aberta durante o teste.'
Write-Host ''

dotnet run --project (Join-Path $Root 'server/src/Bck.Api/Bck.Api.csproj') --no-launch-profile
