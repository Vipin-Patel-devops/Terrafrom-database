#!/usr/bin/env bash
# scripts/restore.sh
# Restores a backup dump into a FRESH database (hotel_bookings_restore_test)
# inside the same postgres container, so we never touch the original data
# and can verify the restore independently.
#
# Usage:
#   ./scripts/restore.sh                     # restores backups/latest.dump
#   ./scripts/restore.sh path/to/file.dump   # restores a specific file

set -euo pipefail

CONTAINER_NAME="${DB_CONTAINER:-hotel_bookings_db}"
DB_USER="${DB_USER:-hotel_admin}"
RESTORE_DB="${RESTORE_DB:-hotel_bookings_restore_test}"
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups"

BACKUP_FILE="${1:-${BACKUP_DIR}/latest.dump}"

if [ ! -e "${BACKUP_FILE}" ]; then
    echo "ERROR: Backup file not found: ${BACKUP_FILE}" >&2
    echo "Run ./scripts/backup.sh first, or pass a path explicitly." >&2
    exit 1
fi

echo "==> Checking container '${CONTAINER_NAME}' is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '${CONTAINER_NAME}' is not running. Run 'docker compose up -d' first." >&2
    exit 1
fi

echo "==> Dropping and recreating fresh database '${RESTORE_DB}'..."
docker exec -i "${CONTAINER_NAME}" psql -U "${DB_USER}" -d postgres \
    -c "DROP DATABASE IF EXISTS ${RESTORE_DB};"
docker exec -i "${CONTAINER_NAME}" psql -U "${DB_USER}" -d postgres \
    -c "CREATE DATABASE ${RESTORE_DB};"

echo "==> Restoring $(basename "$(readlink -f "${BACKUP_FILE}")") into '${RESTORE_DB}'..."
docker exec -i "${CONTAINER_NAME}" pg_restore -U "${DB_USER}" -d "${RESTORE_DB}" --no-owner < "${BACKUP_FILE}"

echo "==> Verifying restore..."
ORIGINAL_COUNT=$(docker exec -i "${CONTAINER_NAME}" psql -U "${DB_USER}" -d hotel_bookings -t -c "SELECT COUNT(*) FROM hotel_bookings;" | tr -d '[:space:]')
RESTORED_COUNT=$(docker exec -i "${CONTAINER_NAME}" psql -U "${DB_USER}" -d "${RESTORE_DB}" -t -c "SELECT COUNT(*) FROM hotel_bookings;" | tr -d '[:space:]')

echo "    hotel_bookings row count (original):  ${ORIGINAL_COUNT}"
echo "    hotel_bookings row count (restored):  ${RESTORED_COUNT}"

if [ "${ORIGINAL_COUNT}" == "${RESTORED_COUNT}" ]; then
    echo "==> SUCCESS: Restore verified, row counts match."
else
    echo "==> WARNING: Row counts differ. Investigate before trusting this backup." >&2
    exit 1
fi
