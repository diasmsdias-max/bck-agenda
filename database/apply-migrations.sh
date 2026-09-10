#!/usr/bin/env sh
set -eu

: "${BCK_POSTGRES_CONNECTION:?BCK_POSTGRES_CONNECTION must be set}"

for migration in "$(dirname "$0")"/migrations/*.sql; do
  echo "Applying $migration"
  psql "$BCK_POSTGRES_CONNECTION" -v ON_ERROR_STOP=1 -f "$migration"
done

echo "BCK Agenda migrations applied successfully."
