#!/usr/bin/env bash
# Daily encrypted dump of all non-system postgres databases.
# Runs as a sidecar task alongside the postgres job.
# Required env vars (injected by Nomad template):
#   PGPASSWORD    - postgres superuser password
#   PGBACKUP_KEY  - passphrase for openssl encryption
set -euo pipefail

PGHOST=127.0.0.1
PGUSER=postgres
BACKUP_DIR=/backup

until pg_isready -h "$PGHOST" -U "$PGUSER" -q; do
  echo "Waiting for postgres..."
  sleep 5
done

while true; do
  echo "Starting backup at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

  DATABASES=$(psql -h "$PGHOST" -U "$PGUSER" -t -A \
    -c "SELECT datname FROM pg_database WHERE datistemplate = false")

  for db in $DATABASES; do
    echo "Backing up ${db}..."
    pg_dump -h "$PGHOST" -U "$PGUSER" "$db" \
      | openssl enc -aes-256-cbc -pbkdf2 -pass env:PGBACKUP_KEY \
      > "$BACKUP_DIR/${db}.sql.enc"
    echo "Done: ${db}.sql.enc"
  done

  echo "Backup complete. Sleeping 24h."
  sleep 86400
done
