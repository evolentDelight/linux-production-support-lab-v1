#!/usr/bin/env bash
set -uo pipefail

SERVICE_NAME="linux-production-support-lab-v1"
APP_UNIT="${SERVICE_NAME}.service"
HEALTHCHECK_UNIT="${SERVICE_NAME}-healthcheck.service"
HEALTHCHECK_TIMER="${SERVICE_NAME}-healthcheck.timer"

CONFIG_DIR="/etc/${SERVICE_NAME}"
CONFIG_FILE="${CONFIG_DIR}/app.env"

APP_DIR="/opt/${SERVICE_NAME}"
SCRIPT_DIR="${APP_DIR}/scripts"
DOCS_DIR="${APP_DIR}/docs"

LOG_DIR="/var/log/${SERVICE_NAME}"
BACKUP_DIR="/var/backups/${SERVICE_NAME}"

NGINX_AVAILABLE="/etc/nginx/sites-available/${SERVICE_NAME}.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/${SERVICE_NAME}.conf"
NGINX_DEFAULT="/etc/nginx/sites-enabled/default"
LOGROTATE_CONFIG="/etc/logrotate.d/${SERVICE_NAME}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  ((PASS_COUNT += 1))
}

warn() {
  printf '[WARN] %s\n' "$1"
  ((WARN_COUNT += 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  ((FAIL_COUNT += 1))
}

section() {
  printf '\n== %s ==\n' "$1"
}

if [[ "$EUID" -ne 0 ]]; then
  echo "[ERROR] Run this readiness check with sudo." >&2
  exit 2
fi

check_command() {
  local command_name="$1"

  if command -v "$command_name" >/dev/null 2>&1; then
    pass "Required command is available: $command_name"
  else
    fail "Required command is missing: $command_name"
  fi
}

check_active() {
  local unit="$1"

  if systemctl is-active --quiet "$unit"; then
    pass "$unit is active"
  else
    fail "$unit is not active"
  fi
}

check_enabled() {
  local unit="$1"

  if systemctl is-enabled --quiet "$unit"; then
    pass "$unit is enabled"
  else
    fail "$unit is not enabled"
  fi
}

check_path_permissions() {
  local path="$1"
  local expected_owner="$2"
  local expected_group="$3"
  local expected_mode="$4"
  local actual_owner
  local actual_group
  local actual_mode

  if [[ ! -e "$path" ]]; then
    fail "Required path is missing: $path"
    return
  fi

  actual_owner="$(stat -c '%U' "$path")"
  actual_group="$(stat -c '%G' "$path")"
  actual_mode="$(stat -c '%a' "$path")"

  if [[ "$actual_owner" == "$expected_owner" &&
        "$actual_group" == "$expected_group" &&
        "$actual_mode" == "$expected_mode" ]]; then
    pass "$path has ${expected_owner}:${expected_group} mode ${expected_mode}"
  else
    fail "$path has ${actual_owner}:${actual_group} mode ${actual_mode}; expected ${expected_owner}:${expected_group} mode ${expected_mode}"
  fi
}

check_env_value() {
  local key="$1"
  local expected_value="$2"

  if grep -Fqx "${key}=${expected_value}" "$CONFIG_FILE"; then
    pass "$key has the expected production value"
  else
    fail "$key is missing or has an unexpected value"
  fi
}

check_env_present() {
  local key="$1"

  if grep -Eq "^${key}=.+$" "$CONFIG_FILE"; then
    pass "$key is present and non-empty"
  else
    fail "$key is missing or empty"
  fi
}

check_endpoint() {
  local name="$1"
  local url="$2"
  local expected_text="$3"
  local temporary_file
  local http_code
  local body

  temporary_file="$(mktemp)"

  if ! http_code="$(
    curl -sS \
      --max-time 5 \
      --output "$temporary_file" \
      --write-out '%{http_code}' \
      "$url"
  )"; then
    rm -f "$temporary_file"
    fail "$name request could not be completed: $url"
    return
  fi

  body="$(cat "$temporary_file")"
  rm -f "$temporary_file"

  if [[ "$http_code" != "200" ]]; then
    fail "$name returned HTTP $http_code instead of 200"
    return
  fi

  if grep -Fq "$expected_text" <<< "$body"; then
    pass "$name returned HTTP 200 with the expected response"
  else
    fail "$name returned HTTP 200 but the response body was unexpected"
  fi
}

check_script() {
  local script_path="$1"

  if [[ ! -f "$script_path" ]]; then
    fail "Script is missing: $script_path"
    return
  fi

  if [[ ! -x "$script_path" ]]; then
    fail "Script is not executable: $script_path"
    return
  fi

  if bash -n "$script_path"; then
    pass "Script exists, is executable, and passes syntax validation: $script_path"
  else
    fail "Script contains a Bash syntax error: $script_path"
  fi
}

check_document() {
  local document_path="$1"

  if [[ -s "$document_path" ]]; then
    pass "Documentation exists and is not empty: $document_path"
  else
    fail "Documentation is missing or empty: $document_path"
  fi
}

printf 'Linux Production Support Lab v1\n'
printf 'Production Readiness Check\n'
printf 'Timestamp: %s\n' "$(date -Is)"

section "Required Tools"

for command_name in \
  curl \
  systemctl \
  journalctl \
  nginx \
  pg_lsclusters \
  psql \
  pg_dump \
  logrotate \
  ss \
  stat \
  grep \
  find; do
  check_command "$command_name"
done

section "Services"

check_active "$APP_UNIT"
check_enabled "$APP_UNIT"

check_active "nginx.service"
check_enabled "nginx.service"

check_active "postgresql.service"
check_enabled "postgresql.service"

check_active "$HEALTHCHECK_TIMER"
check_enabled "$HEALTHCHECK_TIMER"

if pg_lsclusters --no-header | awk '$4 == "online" { found=1 } END { exit !found }'; then
  pass "At least one PostgreSQL cluster is online"
else
  fail "No PostgreSQL cluster is online"
fi

section "Application Health"

check_endpoint \
  "Nginx application health endpoint" \
  "http://localhost/health" \
  '"status":"ok"'

check_endpoint \
  "Nginx database health endpoint" \
  "http://localhost/db-health" \
  '"database":"connected"'

check_endpoint \
  "Nginx tickets endpoint" \
  "http://localhost/tickets" \
  '"count":'

check_endpoint \
  "Direct Node.js health endpoint" \
  "http://127.0.0.1:3000/health" \
  '"status":"ok"'

section "Configuration and Permissions"

check_path_permissions "$CONFIG_DIR" "root" "prodapp" "750"
check_path_permissions "$CONFIG_FILE" "root" "prodapp" "640"

if [[ -r "$CONFIG_FILE" ]]; then
  check_env_value "HOST" "127.0.0.1"
  check_env_value "PORT" "3000"
  check_env_value "SERVICE_NAME" "$SERVICE_NAME"
  check_env_value "APP_ENV" "production"
  check_env_value "LOG_DIR" "$LOG_DIR"
  check_env_present "APP_VERSION"
  check_env_present "LOG_LEVEL"
  check_env_present "DATABASE_URL"
else
  fail "Cannot inspect required variables because $CONFIG_FILE is unreadable"
fi

if [[ -d "$APP_DIR" ]]; then
  app_owner="$(stat -c '%U' "$APP_DIR")"
  app_group="$(stat -c '%G' "$APP_DIR")"

  if [[ "$app_owner" == "prodapp" && "$app_group" == "prodapp" ]]; then
    pass "$APP_DIR is owned by prodapp:prodapp"
  else
    fail "$APP_DIR is owned by ${app_owner}:${app_group}; expected prodapp:prodapp"
  fi
else
  fail "Deployed application directory is missing: $APP_DIR"
fi

section "Nginx"

if [[ -f "$NGINX_AVAILABLE" ]]; then
  pass "Nginx site configuration exists"
else
  fail "Nginx site configuration is missing: $NGINX_AVAILABLE"
fi

if [[ -L "$NGINX_ENABLED" ]]; then
  pass "Nginx site configuration is enabled with a symbolic link"
else
  fail "Nginx site configuration is not enabled as a symbolic link"
fi

if [[ ! -e "$NGINX_DEFAULT" ]]; then
  pass "Default Nginx site is disabled"
else
  warn "Default Nginx site is still enabled"
fi

if nginx -t >/dev/null 2>&1; then
  pass "Nginx configuration passes validation"
else
  fail "Nginx configuration validation failed"
fi

if grep -Fq \
  'proxy_pass http://127.0.0.1:3000;' \
  "$NGINX_AVAILABLE" 2>/dev/null; then
  pass "Nginx proxies to the expected Node.js port"
else
  fail "Nginx does not proxy to http://127.0.0.1:3000"
fi

section "Logging"

check_path_permissions "$LOG_DIR" "prodapp" "prodapp" "755"

for log_file in app.log error.log monitor.log alerts.log; do
  if [[ -f "${LOG_DIR}/${log_file}" ]]; then
    pass "Log file exists: ${LOG_DIR}/${log_file}"
  else
    warn "Log file does not currently exist: ${LOG_DIR}/${log_file}"
  fi
done

if [[ -f "$LOGROTATE_CONFIG" ]]; then
  pass "Logrotate configuration exists"

  if logrotate -d "$LOGROTATE_CONFIG" >/dev/null 2>&1; then
    pass "Logrotate configuration passes debug validation"
  else
    fail "Logrotate configuration validation failed"
  fi
else
  fail "Logrotate configuration is missing"
fi

section "Scripts"

check_script "${SCRIPT_DIR}/backup-db.sh"
check_script "${SCRIPT_DIR}/restore-db.sh"
check_script "${SCRIPT_DIR}/health-check.sh"
check_script "${SCRIPT_DIR}/readiness-check.sh"

section "Backup and Recovery"

check_path_permissions "$BACKUP_DIR" "prodapp" "prodapp" "750"

LATEST_BACKUP="$(
  find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'support_tickets_*.sql' \
    -printf '%T@ %p\n' 2>/dev/null |
    sort -nr |
    head -n 1 |
    cut -d' ' -f2-
)"

if [[ -n "$LATEST_BACKUP" && -f "$LATEST_BACKUP" ]]; then
  pass "At least one support_tickets backup exists"

  backup_owner="$(stat -c '%U' "$LATEST_BACKUP")"
  backup_group="$(stat -c '%G' "$LATEST_BACKUP")"
  backup_mode="$(stat -c '%a' "$LATEST_BACKUP")"

  if [[ "$backup_owner" == "prodapp" &&
        "$backup_group" == "prodapp" &&
        "$backup_mode" == "640" ]]; then
    pass "Latest backup has prodapp:prodapp ownership and mode 640"
  else
    warn "Latest backup has ${backup_owner}:${backup_group} mode ${backup_mode}"
  fi

  current_time="$(date +%s)"
  backup_time="$(stat -c '%Y' "$LATEST_BACKUP")"
  backup_age_days="$(( (current_time - backup_time ) / 86400 ))"

  if (( backup_age_days <= 7 )); then
    pass "Latest backup is ${backup_age_days} day(s) old"
  else
    warn "Latest backup is ${backup_age_days} days old"
  fi
else
  fail "No support_tickets backup files were found"
fi

section "Monitoring"

if [[ -f "/etc/systemd/system/${HEALTHCHECK_UNIT}" ]]; then
  pass "Health-check systemd service is installed"
else
  fail "Health-check systemd service is missing"
fi

if [[ -f "/etc/systemd/system/${HEALTHCHECK_TIMER}" ]]; then
  pass "Health-check systemd timer is installed"
else
  fail "Health-check systemd timer is missing"
fi

if grep -Eq \
  '^Wants=.*linux-production-support-lab-v1\.service' \
  "/etc/systemd/system/${HEALTHCHECK_UNIT}" 2>/dev/null; then
  fail "Health-check service still activates the application through Wants="
else
  pass "Health-check service does not automatically activate the application"
fi

healthcheck_result="$(
  systemctl show "$HEALTHCHECK_UNIT" \
    --property=Result \
    --value 2>/dev/null
)"

if [[ "$healthcheck_result" == "success" ]]; then
  pass "Most recent systemd health-check result was successful"
else
  warn "Most recent systemd health-check result is ${healthcheck_result:-unknown}"
fi

section "Documentation"

check_document "${APP_DIR}/README.md"
check_document "${DOCS_DIR}/backup-restore.md"
check_document "${DOCS_DIR}/monitoring.md"
check_document "${DOCS_DIR}/troubleshooting-drills.md"
check_document "${DOCS_DIR}/production-readiness-checklist.md"

section "Summary"

printf '[SUMMARY] PASS=%d WARN=%d FAIL=%d\n' \
  "$PASS_COUNT" \
  "$WARN_COUNT" \
  "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
  echo "[RESULT] NOT READY"
  exit 1
fi

if (( WARN_COUNT > 0 )); then
  echo "[RESULT] READY WITH WARNINGS"
  exit 0
fi

echo "[RESULT] READY"
exit 0