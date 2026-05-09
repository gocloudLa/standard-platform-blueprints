#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Sync all Grafana dashboards from resources/dashboards/ to a Grafana instance.
#
# Requirements:
#   - GRAFANA_URL : Base URL of your Grafana instance (e.g. https://grafana.lab.example.com)
#   - GRAFANA_TOKEN : Service Account token with "Editor" role
#   - curl, jq installed
#
# Usage:
#   export GRAFANA_URL="https://grafana.lab.example.com"
#   export GRAFANA_TOKEN="glsa_xxxxxxxxxxxx"
#   ./scripts/sync-dashboards.sh
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  source "${SCRIPT_DIR}/.env"
  set +a
fi
# -------
set -euo pipefail

DASHBOARDS_DIR="${1:-dashboards}"
FOLDER_TITLE="${GRAFANA_FOLDER:-General}"

# --- Validations -----------------------------------------------------------
if [[ -z "${GRAFANA_URL:-}" ]]; then
  echo "ERROR: GRAFANA_URL is not set." >&2
  exit 1
fi

if [[ -z "${GRAFANA_TOKEN:-}" ]]; then
  echo "ERROR: GRAFANA_TOKEN is not set." >&2
  echo "" >&2
  echo "To create one in Grafana:" >&2
  echo "  1. Go to Administration > Service Accounts" >&2
  echo "  2. Create a Service Account with 'Editor' role" >&2
  echo "  3. Add a token and export it as GRAFANA_TOKEN" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

# Remove trailing slash from URL
GRAFANA_URL="${GRAFANA_URL%/}"

# --- Resolve or create target folder ---------------------------------------
get_folder_id() {
  if [[ "$FOLDER_TITLE" == "General" ]]; then
    echo "null"
    return
  fi

  local folder_uid
  folder_uid=$(curl -sf -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
    "${GRAFANA_URL}/api/folders" | jq -r ".[] | select(.title==\"${FOLDER_TITLE}\") | .uid")

  if [[ -z "$folder_uid" ]]; then
    # Create the folder
    folder_uid=$(curl -sf -X POST -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"title\": \"${FOLDER_TITLE}\"}" \
      "${GRAFANA_URL}/api/folders" | jq -r '.uid')
    echo "Created folder '${FOLDER_TITLE}' (uid: ${folder_uid})" >&2
  fi

  echo "\"${folder_uid}\""
}

FOLDER_UID=$(get_folder_id)

# --- Sync each dashboard ---------------------------------------------------
success=0
failed=0

for file in "${DASHBOARDS_DIR}"/*.json; do
  [[ -f "$file" ]] || continue

  filename=$(basename "$file")
  dashboard_title=$(jq -r '.title // "Untitled"' "$file")
  dashboard_uid=$(jq -r '.uid // empty' "$file")

  echo -n "Syncing: ${dashboard_title} (${filename}) ... "

  # Wrap the dashboard JSON in the import/create-or-update payload
  payload=$(jq -n \
    --argjson dashboard "$(jq '.' "$file")" \
    --argjson folderUid "$FOLDER_UID" \
    '{
      dashboard: ($dashboard | .id = null | .version = null),
      folderUid: $folderUid,
      overwrite: true,
      message: "Synced by sync-dashboards.sh"
    }')

  response=$(curl -sf -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${GRAFANA_URL}/api/dashboards/db" 2>&1) || true

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    url=$(echo "$body" | jq -r '.url // empty')
    echo "✓ ${GRAFANA_URL}${url}"
    ((success++))
  else
    echo "✗ HTTP ${http_code}"
    echo "  Response: ${body}" >&2
    ((failed++))
  fi
done

echo ""
echo "Done: ${success} synced, ${failed} failed."
[[ $failed -eq 0 ]] || exit 1
