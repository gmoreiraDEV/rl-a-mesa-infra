#!/usr/bin/env bash
set -euo pipefail

if [[ "${SMOKE_TARGET:-}" != "staging" ]]; then
  echo "Smoke refused: set SMOKE_TARGET=staging." >&2
  exit 2
fi

: "${STAGING_API_URL:?STAGING_API_URL is required}"
: "${STAGING_APP_URL:?STAGING_APP_URL is required}"
: "${STAGING_BACKOFFICE_URL:?STAGING_BACKOFFICE_URL is required}"
: "${STAGING_MEMBER_TOKEN:?STAGING_MEMBER_TOKEN is required}"
: "${STAGING_ADMIN_TOKEN:?STAGING_ADMIN_TOKEN is required}"

api_url="${STAGING_API_URL%/}"
app_url="${STAGING_APP_URL%/}"
backoffice_url="${STAGING_BACKOFFICE_URL%/}"
foreign_contract_id="${STAGING_FOREIGN_CONTRACT_ID:-81000000-0000-0000-0000-000000000001}"
response_body="$(mktemp)"
trap 'rm -f "$response_body"' EXIT

expect_status() {
  local expected="$1"
  local url="$2"
  shift 2
  local status
  status="$(curl --silent --show-error --output "$response_body" --write-out "%{http_code}" "$@" "$url")"
  if [[ "$status" != "$expected" ]]; then
    echo "Smoke failed for ${url}: expected ${expected}, received ${status}." >&2
    return 1
  fi
}

expect_status 200 "${api_url}/health"
expect_status 200 "${api_url}/api/v1/products"
python3 - "$response_body" <<'PY'
import json
import sys

products = json.load(open(sys.argv[1], encoding="utf-8"))
slugs = {item["slug"] for item in products}
required = {"a-mesa", "air-fryer-todo-dia", "casa-lima", "cha"}
if not required.issubset(slugs):
    raise SystemExit(f"Missing demo products: {sorted(required - slugs)}")
PY

expect_status 401 "${api_url}/api/v1/me/library"
expect_status 200 "${api_url}/api/v1/me/library" \
  --header "Authorization: Bearer ${STAGING_MEMBER_TOKEN}"
python3 - "$response_body" <<'PY'
import json
import sys

library = json.load(open(sys.argv[1], encoding="utf-8"))
if not any(item.get("slug") == "a-mesa" for item in library):
    raise SystemExit("Demo member library does not contain À Mesa")
PY

expect_status 403 "${api_url}/api/v1/me/contracts/${foreign_contract_id}" \
  --header "Authorization: Bearer ${STAGING_MEMBER_TOKEN}"
expect_status 200 "${api_url}/api/v1/admin/audit/dashboard" \
  --header "Authorization: Bearer ${STAGING_ADMIN_TOKEN}"
expect_status 200 "${app_url}/produtos"
expect_status 200 "${backoffice_url}/robots.txt"
if ! grep -qi "disallow: /" "$response_body"; then
  echo "Backoffice robots.txt does not block indexing." >&2
  exit 1
fi

echo "Staging smoke passed without creating charges or mutating customer data."
