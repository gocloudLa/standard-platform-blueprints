#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Create Grafana datasources for the Observability Stack.
# Idempotent: updates existing datasources if they already exist.
#
# Requires: GRAFANA_URL, GRAFANA_TOKEN (same as sync-dashboards.sh)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  source "${SCRIPT_DIR}/.env"
  set +a
fi
# ---------------------------------------------------------------------------
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL%/}"

create_or_update_datasource() {
  local name="$1"
  local payload="$2"

  # Check if datasource exists
  local existing
  existing=$(curl -sf -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
    "${GRAFANA_URL}/api/datasources/name/${name}" 2>/dev/null) || true

  if [[ -n "$existing" ]]; then
    local uid
    uid=$(echo "$existing" | jq -r '.uid')
    echo -n "Updating: ${name} ... "
    curl -sf -X PUT \
      -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "${GRAFANA_URL}/api/datasources/uid/${uid}" > /dev/null
    echo "✓ (updated)"
  else
    echo -n "Creating: ${name} ... "
    curl -sf -X POST \
      -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "${GRAFANA_URL}/api/datasources" > /dev/null
    echo "✓ (created)"
  fi
}

# --- Prometheus (Mimir) ----------------------------------------------------
create_or_update_datasource "Prometheus" "$(cat <<'EOF'
{
  "name": "Prometheus",
  "type": "prometheus",
  "access": "proxy",
  "url": "http://mimir.lab.democorp.internal:9009/prometheus",
  "isDefault": true,
  "jsonData": {
    "timeInterval": "15s",
    "httpMethod": "POST"
  }
}
EOF
)"

# --- Tempo (needs Prometheus UID for trace-to-metrics) ---------------------
PROMETHEUS_UID=$(curl -sf -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
  "${GRAFANA_URL}/api/datasources/name/Prometheus" | jq -r '.uid')

create_or_update_datasource "Tempo" "$(cat <<EOF
{
  "name": "Tempo",
  "type": "tempo",
  "access": "proxy",
  "url": "http://tempo.lab.democorp.internal:3200",
  "jsonData": {
    "tracesToMetrics": {
      "datasourceUid": "${PROMETHEUS_UID}",
      "spanStartTimeShift": "-1h",
      "spanEndTimeShift": "1h"
    },
    "nodeGraph": {
      "enabled": true
    },
    "serviceMap": {
      "datasourceUid": "${PROMETHEUS_UID}"
    }
  }
}
EOF
)"

# --- CloudWatch ------------------------------------------------------------
create_or_update_datasource "CloudWatch" "$(cat <<'EOF'
{
  "name": "CloudWatch",
  "type": "cloudwatch",
  "access": "proxy",
  "jsonData": {
    "authType": "default",
    "defaultRegion": "us-east-2"
  }
}
EOF
)"

# --- Loki ------------------------------------------------------------------
TEMPO_UID=$(curl -sf -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
  "${GRAFANA_URL}/api/datasources/name/Tempo" | jq -r '.uid')

create_or_update_datasource "Loki" "$(cat <<EOF
{
  "name": "Loki",
  "type": "loki",
  "access": "proxy",
  "url": "http://loki.lab.democorp.internal:3100",
  "jsonData": {
    "derivedFields": [
      {
        "datasourceUid": "${TEMPO_UID}",
        "matcherType": "regex",
        "matcherRegex": "(?:(?:\"traceID\"|\"trace_id\")\\\\s*:\\\\s*\"|traceID=)([a-fA-F0-9]+)",
        "name": "traceID",
        "url": "\${__value.raw}",
        "urlDisplayLabel": "View Trace"
      }
    ]
  }
}
EOF
)"

echo ""
echo "Done. Datasources configured."
