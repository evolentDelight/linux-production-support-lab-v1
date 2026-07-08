#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/linux-production-support-lab-v1/app.env"
BACKUP_DIR="/var/backups/linux-production-support-lab-v1"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/support_tickets_${TIMESTAMP}.sql"

if [[ ! -r "$CONFIG_FILE" ]]; then
  echo "[ERROR] Cannot read config file: $CONFIG_FILE" >&2
  exit 1
fi

set -a
source "$CONFIG_FILE"
set +a

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "[ERROR] DATABASE_URL is not set in $CONFIG_FILE" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
umask 027

echo "[INFO] Creating backup: $BACKUP_FILE"

pg_dump "$DATABASE_URL" \
  --data-only \
  --table=public.support_tickets \
  --column-inserts \
  --file="$BACKUP_FILE"

chmod 640 "$BACKUP_FILE"

echo "[INFO] Backup completed successfully"
echo "[INFO] Backup file: $BACKUP_FILE"