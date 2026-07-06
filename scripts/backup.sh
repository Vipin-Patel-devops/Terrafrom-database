#!/usr/bin/env bash
# scripts/backup.sh
# Creates a timestamped logical dump of the local hotel_bookings database
# running in the "hotel_bookings_db" docker-compose container.

set -euo pipefail

CONTAINER_NAME="${DB_CONTAINER:-hotel_bookings_db}"
DB_USER="${DB_USER:-hotel_admin}"
DB_NAME="${DB_NAME:-hotel_bookings}"
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups"

mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/hotel_bookings_${TIMESTAMP}.dump"

echo "==> Checking container '${CONTAINER_NAME}' is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '${CONTAINER_NAME}' is not running. Run 'docker compose up -d' first." >&2
    exit 1
fi

echo "==> Creating backup: ${BACKUP_FILE}"
docker exec -i "${CONTAINER_NAME}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" -F c > "${BACKUP_FILE}"

echo "==> Backup complete."
echo "    File: ${BACKUP_FILE}"
echo "    Size: $(du -h "${BACKUP_FILE}" | cut -f1)"

# Keep a convenient pointer to the most recent backup
ln -sf "$(basename "${BACKUP_FILE}")" "${BACKUP_DIR}/latest.dump"
echo "    Symlink updated: ${BACKUP_DIR}/latest.dump -> $(basename "${BACKUP_FILE}")"
