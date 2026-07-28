#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL is required}"
: "${BACKUP_DIR:?BACKUP_DIR is required}"

umask 077
mkdir -p "${BACKUP_DIR}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_path="${BACKUP_DIR%/}/a-mesa-${timestamp}.dump"

pg_dump --format=custom --no-owner --no-privileges \
  --file="${backup_path}" "${DATABASE_URL}"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${backup_path}" > "${backup_path}.sha256"
else
  shasum -a 256 "${backup_path}" > "${backup_path}.sha256"
fi

echo "Backup created: ${backup_path}"
