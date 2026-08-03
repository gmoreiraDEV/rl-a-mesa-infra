#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Keycloak provisioning failed at line ${LINENO}." >&2' ERR

: "${KEYCLOAK_URL:?KEYCLOAK_URL is required}"
: "${KEYCLOAK_ADMIN_USERNAME:?KEYCLOAK_ADMIN_USERNAME is required}"
: "${KEYCLOAK_ADMIN_PASSWORD:?KEYCLOAK_ADMIN_PASSWORD is required}"
: "${APP_PUBLIC_URL:?APP_PUBLIC_URL is required}"
: "${BACKOFFICE_PUBLIC_URL:?BACKOFFICE_PUBLIC_URL is required}"
: "${KEYCLOAK_SERVICE_CLIENT_SECRET:?KEYCLOAK_SERVICE_CLIENT_SECRET is required}"

base_url="${KEYCLOAK_URL%/}"
token="$(curl --fail --silent --show-error \
  --data-urlencode grant_type=password \
  --data-urlencode client_id=admin-cli \
  --data-urlencode "username=${KEYCLOAK_ADMIN_USERNAME}" \
  --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
  "${base_url}/realms/master/protocol/openid-connect/token" | jq --exit-status --raw-output .access_token)"
auth_header="Authorization: Bearer ${token}"

ensure_realm() {
  local realm="$1"
  local status
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --header "${auth_header}" "${base_url}/admin/realms/${realm}")"
  if [[ "${status}" == "404" ]]; then
    jq --null-input --arg realm "${realm}" '{realm:$realm,enabled:true}' | \
      curl --fail --silent --show-error --request POST \
        --header "${auth_header}" --header 'Content-Type: application/json' \
        --data-binary @- "${base_url}/admin/realms"
  elif [[ "${status}" != "200" ]]; then
    echo "Unable to inspect realm ${realm}: HTTP ${status}" >&2
    return 1
  fi
}

ensure_role() {
  local realm="$1"
  local role="$2"
  local status
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --header "${auth_header}" "${base_url}/admin/realms/${realm}/roles/${role}")"
  if [[ "${status}" == "404" ]]; then
    jq --null-input --arg name "${role}" '{name:$name}' | \
      curl --fail --silent --show-error --request POST \
        --header "${auth_header}" --header 'Content-Type: application/json' \
        --data-binary @- "${base_url}/admin/realms/${realm}/roles"
  elif [[ "${status}" != "200" ]]; then
    echo "Unable to inspect role ${realm}/${role}: HTTP ${status}" >&2
    return 1
  fi
}

client_uuid() {
  local realm="$1"
  local client_id="$2"
  curl --fail --silent --show-error --get --header "${auth_header}" \
    --data-urlencode "clientId=${client_id}" \
    "${base_url}/admin/realms/${realm}/clients" | jq --exit-status --raw-output '.[0].id'
}

ensure_client() {
  local realm="$1"
  local payload="$2"
  local client_id
  local uuid
  client_id="$(jq --raw-output .clientId <<<"${payload}")"
  uuid="$(client_uuid "${realm}" "${client_id}" 2>/dev/null || true)"
  if [[ -z "${uuid}" || "${uuid}" == "null" ]]; then
    curl --fail --silent --show-error --request POST \
      --header "${auth_header}" --header 'Content-Type: application/json' \
      --data-binary "${payload}" "${base_url}/admin/realms/${realm}/clients"
    uuid="$(client_uuid "${realm}" "${client_id}")"
  else
    curl --fail --silent --show-error --request PUT \
      --header "${auth_header}" --header 'Content-Type: application/json' \
      --data-binary "${payload}" "${base_url}/admin/realms/${realm}/clients/${uuid}"
  fi
  printf '%s' "${uuid}"
}

ensure_audience_mapper() {
  local realm="$1"
  local uuid="$2"
  local existing
  existing="$(curl --fail --silent --show-error --header "${auth_header}" \
    "${base_url}/admin/realms/${realm}/clients/${uuid}/protocol-mappers/models" | \
    jq --raw-output '.[] | select(.name == "a-mesa-api-audience") | .id' | head -n 1)"
  if [[ -z "${existing}" ]]; then
    jq --null-input '{
      name:"a-mesa-api-audience",
      protocol:"openid-connect",
      protocolMapper:"oidc-audience-mapper",
      consentRequired:false,
      config:{
        "included.client.audience":"a-mesa-api",
        "id.token.claim":"false",
        "access.token.claim":"true"
      }
    }' | curl --fail --silent --show-error --request POST \
      --header "${auth_header}" --header 'Content-Type: application/json' \
      --data-binary @- "${base_url}/admin/realms/${realm}/clients/${uuid}/protocol-mappers/models"
  fi
}

public_client_payload() {
  local client_id="$1"
  local public_url="$2"
  jq --null-input --arg client_id "${client_id}" --arg public_url "${public_url}" '{
    clientId:$client_id,
    enabled:true,
    publicClient:true,
    standardFlowEnabled:true,
    directAccessGrantsEnabled:false,
    implicitFlowEnabled:false,
    redirectUris:[($public_url + "/*")],
    webOrigins:[$public_url],
    attributes:{
      "pkce.code.challenge.method":"S256",
      "post.logout.redirect.uris":($public_url + "/*")
    }
  }'
}

api_client_payload='{"clientId":"a-mesa-api","enabled":true,"bearerOnly":true,"publicClient":false,"standardFlowEnabled":false,"directAccessGrantsEnabled":false}'

ensure_realm a-mesa
ensure_realm a-mesa-admin
for role in CUSTOMER MEMBER; do ensure_role a-mesa "${role}"; done
for role in ADMIN STAFF; do ensure_role a-mesa-admin "${role}"; done

ensure_client a-mesa "${api_client_payload}" >/dev/null
app_uuid="$(ensure_client a-mesa "$(public_client_payload a-mesa-app "${APP_PUBLIC_URL}")")"
ensure_audience_mapper a-mesa "${app_uuid}"

ensure_client a-mesa-admin "${api_client_payload}" >/dev/null
backoffice_uuid="$(ensure_client a-mesa-admin "$(public_client_payload a-mesa-backoffice "${BACKOFFICE_PUBLIC_URL}")")"
ensure_audience_mapper a-mesa-admin "${backoffice_uuid}"

service_payload="$(jq --null-input --arg secret "${KEYCLOAK_SERVICE_CLIENT_SECRET}" '{
  clientId:"a-mesa-identity-service",
  enabled:true,
  publicClient:false,
  secret:$secret,
  serviceAccountsEnabled:true,
  standardFlowEnabled:false,
  directAccessGrantsEnabled:false
}')"
service_uuid="$(ensure_client master "${service_payload}")"
service_user_id="$(curl --fail --silent --show-error --header "${auth_header}" \
  "${base_url}/admin/realms/master/clients/${service_uuid}/service-account-user" | \
  jq --exit-status --raw-output .id)"
realm_management_uuid="$(client_uuid master master-realm)"
management_roles="$(curl --fail --silent --show-error --header "${auth_header}" \
  "${base_url}/admin/realms/master/clients/${realm_management_uuid}/roles" | \
  jq '[.[] | select(.name == "manage-users" or .name == "query-users" or .name == "view-users")]')"
curl --fail --silent --show-error --request POST \
  --header "${auth_header}" --header 'Content-Type: application/json' \
  --data-binary "${management_roles}" \
  "${base_url}/admin/realms/master/users/${service_user_id}/role-mappings/clients/${realm_management_uuid}"

echo "Keycloak realms and clients are provisioned."
