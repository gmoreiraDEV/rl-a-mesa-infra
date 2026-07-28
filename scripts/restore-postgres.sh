#!/usr/bin/env bash
set -euo pipefail

: "${RESTORE_DATABASE_URL:?RESTORE_DATABASE_URL is required}"
: "${ALLOW_RESTORE:?Set ALLOW_RESTORE=yes after validating the target}"

if [[ "${ALLOW_RESTORE}" != "yes" ]]; then
  echo "Restore refused: ALLOW_RESTORE must equal yes." >&2
  exit 2
fi

backup_path="${1:?Usage: restore-postgres.sh /absolute/path/backup.dump}"
if [[ ! -f "${backup_path}" ]]; then
  echo "Backup file not found." >&2
  exit 2
fi

pg_restore --clean --if-exists --no-owner --no-privileges \
  --dbname="${RESTORE_DATABASE_URL}" "${backup_path}"

echo "Restore completed. Run application smoke tests before releasing traffic."
