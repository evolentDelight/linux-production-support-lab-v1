#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="linux-production-support-lab-v1"
APP_URL="${APP_URL:-http://localhost/health}"
DB_URL="${DB_URL:-http://localhost/db-health}"
LOG_DIR="/var/log/linux-production-support-lab-v1"
MONITOR_LOG="${LOG_DIR}/monitor.log"
ALERT_LOG="${LOG_DIR}/alerts.log"
TIMESTAMP="$(date -Is)"

mkdir -p "$LOG_DIR"

check_endpoint() {
  local name="$1"
  local url="$2"
  local response
  local http_code
  local body
  
  response="$(curl -sS --max-time 5 --write-out $'\n%{http_code}' "$url" 2>&1)" || {
    echo "${name}=curl_failed message=\"${response}\""
    return 1
  }

  http_code="$(printf "%s\n" "$response" | tail -n 1)"
  body="$(printf "%s\n" "$response" | sed '$d')"

  if [[ "$http_code" != "200" ]]; then
    echo "${name}=bad_http_status http_code=${http_code} body=\"${body}\""
    return 1
  fi

  if ! grep -q '"status":"ok"' <<< "$body"; then
    echo "${name}=bad_health_body body=\"${body}\""
    return 1
  fi

  echo "${name}=healthy http_code=${http_code}"
  return 0
}

STATUS="ok"
DETAILS=()

if APP_RESULT="$(check_endpoint "app" "$APP_URL")"; then
  DETAILS+=("$APP_RESULT")
else
  STATUS="critical"
  DETAILS+=("$APP_RESULT")
fi

if DB_RESULT="$(check_endpoint "database" "$DB_URL")"; then
  DETAILS+=("$DB_RESULT")
else
  STATUS="critical"
  DETAILS+=("$DB_RESULT")
fi

MESSAGE="${TIMESTAMP} service=${SERVICE_NAME} status=${STATUS} ${DETAILS[*]}"

echo "$MESSAGE" >> "$MONITOR_LOG"

if [[ "$STATUS" != "ok" ]]; then
  echo "$MESSAGE" >> "$ALERT_LOG"
  logger -t "${SERVICE_NAME}-monitor" "$MESSAGE" || true
  echo "$MESSAGE" >&2
  exit 2
fi

echo "$MESSAGE"