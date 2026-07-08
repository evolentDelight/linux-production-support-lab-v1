#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/linux-production-support-lab-v1/app.env"
BACKUP_FILE="${1:-}"
CONFIRM="${2:-}"

if [[ -z "$BACKUP_FILE" ]]; then
  echo "Usage: $0 /path/to/backup.sql --yes" >&2
  exit 1
fi

if [[ "$CONFIRM" != "--yes" ]]; then
  echo "[ERROR] Restore is destructive. Re-run with --yes to confirm." >&2
  echo "Usage: $0 /path/to/backup.sql --yes" >&2
  exit 1
fi

if [[ ! -r "$CONFIG_FILE" ]]; then
  echo "[ERROR] Cannot read config file: $CONFIG_FILE" >&2
  exit 1
fi

if [[ ! -r "$BACKUP_FILE" ]]; then
  echo "[ERROR] Cannot read backup file: $BACKUP_FILE" >&2
  exit 1
fi

set -a
source "$CONFIG_FILE"
set +a

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "[ERROR] DATABASE_URL is not set in $CONFIG_FILE" >&2
  exit 1
fi

echo "[WARN] Restoring backup: $BACKUP_FILE"
echo "[WARN] Existing rows in support_tickets will be deleted first."

psql "$DATABASE_URL" \
  -v ON_ERROR_STOP=1 \
  -c "DELETE FROM support_tickets;"

psql "$DATABASE_URL" \
  -v ON_ERROR_STOP=1 \
  -f "$BACKUP_FILE"

echo "[INFO] Restore completed successfully"