#!/usr/bin/env bash
set -euo pipefail

if [[ "${ENVIRONMENT:-}" == "production" ]]; then
  echo "Restore drill is forbidden in production." >&2
  exit 2
fi
if [[ "${ALLOW_RESTORE_DRILL:-}" != "yes" ]]; then
  echo "Restore drill refused: set ALLOW_RESTORE_DRILL=yes." >&2
  exit 2
fi

: "${RESTORE_DATABASE_URL:?RESTORE_DATABASE_URL is required}"
: "${BACKEND_DIR:?BACKEND_DIR is required}"
backup_path="${1:?Usage: restore-drill.sh /absolute/path/backup.dump}"

if [[ ! -f "$backup_path" ]]; then
  echo "Backup file not found." >&2
  exit 2
fi
if [[ ! -d "$BACKEND_DIR/services" || ! -f "$BACKEND_DIR/pyproject.toml" ]]; then
  echo "BACKEND_DIR does not point to the À MESA backend." >&2
  exit 2
fi

if [[ -f "${backup_path}.sha256" ]]; then
  expected_checksum="$(awk 'NR == 1 {print $1}' "${backup_path}.sha256")"
  if command -v sha256sum >/dev/null 2>&1; then
    actual_checksum="$(sha256sum "$backup_path" | awk '{print $1}')"
  else
    actual_checksum="$(shasum -a 256 "$backup_path" | awk '{print $1}')"
  fi
  if [[ "$actual_checksum" != "$expected_checksum" ]]; then
    echo "Restore drill refused: backup checksum mismatch." >&2
    exit 2
  fi
fi

database_name="$(psql "$RESTORE_DATABASE_URL" --tuples-only --no-align --command "SELECT current_database()")"
if [[ "$database_name" != *_restore_drill ]]; then
  echo "Restore drill target database must end with _restore_drill." >&2
  exit 2
fi

pg_restore --list "$backup_path" >/dev/null
ALLOW_RESTORE=yes RESTORE_DATABASE_URL="$RESTORE_DATABASE_URL" \
  "$(dirname "$0")/restore-postgres.sh" "$backup_path"

migration_configs=(
  identity_service
  customer_service
  access_service
  catalog_service
  content_service
  media_service
  contract_service
  personal_chef_service
  order_service
  billing_service
  notification_service
  audit_service
)

for service in "${migration_configs[@]}"; do
  (
    cd "$BACKEND_DIR"
    database_variable="$(printf '%s' "$service" | tr '[:lower:]' '[:upper:]')_DATABASE_URL"
    database_variable="${database_variable%_SERVICE_DATABASE_URL}_DATABASE_URL"
    env "$database_variable=$RESTORE_DATABASE_URL" \
      uv run --no-sync alembic -c "services/${service}/alembic.ini" upgrade head
  )
done

schema_count="$(psql "$RESTORE_DATABASE_URL" --tuples-only --no-align --command \
  "SELECT count(*) FROM information_schema.schemata WHERE schema_name IN ('identity','customers','access','catalog','content','media','contracts','personal_chef','orders','billing','notifications','audit')")"
if [[ "$schema_count" != "12" ]]; then
  echo "Restore drill failed: expected 12 application schemas, found ${schema_count}." >&2
  exit 1
fi

psql "$RESTORE_DATABASE_URL" --set ON_ERROR_STOP=1 --command \
  "SELECT count(*) AS products FROM catalog.products; SELECT count(*) AS customers FROM customers.profiles;"
echo "Restore drill passed in isolated database ${database_name}. Cleanup remains an explicit operator action."
