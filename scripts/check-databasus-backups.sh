#!/usr/bin/env bash
# check-databasus-backups.sh — verify databasus is backing up all databases.
#
# Lists all non-system databases in PostgreSQL and MySQL, then checks that
# each one has at least one backup file in the databasus CSI volume
# (/databasus-data/backups inside the running alloc).
#
# Requires: nomad CLI, psql, mysql, jq
# Requires: NOMAD_TOKEN set in environment
# Optional: NOMAD_ADDR (default: http://127.0.0.1:4646)

set -euo pipefail

if [[ -z "${NOMAD_TOKEN:-}" ]]; then
    echo "ERROR: NOMAD_TOKEN is not set" >&2
    exit 1
fi

# --- Credentials ---
PGPASSWORD=$(nomad var get -out=json nomad/jobs/postgres | jq -r '.Items.pgpassword')
export PGPASSWORD

MYSQL_PWD=$(nomad var get -out=json nomad/jobs/mysql | jq -r '.Items.root_password')
export MYSQL_PWD

# --- Databases ---
echo "==> Listing PostgreSQL databases..."
PG_DBS=$(psql -h postgres.service.home.consul -U postgres -t -A \
    -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';")

echo "==> Listing MySQL databases..."
MYSQL_DBS=$(mysql -h mysql.service.home.consul -u root --batch --skip-column-names \
    -e "SHOW DATABASES;" \
    | grep -vE '^(information_schema|performance_schema|mysql|sys)$')

# --- Find running databasus alloc ---
echo "==> Finding databasus allocation..."
ALLOC_ID=$(nomad job allocs -json databasus \
    | jq -r '[.[] | select(.ClientStatus == "running")] | .[0].ID')

if [[ "$ALLOC_ID" == "null" || -z "$ALLOC_ID" ]]; then
    echo "ERROR: no running databasus allocation found" >&2
    exit 1
fi

echo "    alloc: $ALLOC_ID"

# --- List backup files via exec into the alloc ---
echo "==> Listing /databasus-data/backups..."
BACKUPS=$(nomad alloc exec -task databasus "$ALLOC_ID" ls /databasus-data/backups 2>/dev/null || true)

if [[ -z "$BACKUPS" ]]; then
    echo "WARNING: backup directory is empty or unreadable" >&2
fi

# --- Check each database has a backup ---
PASS=0
FAIL=0

check_db() {
    local engine="$1"
    local db="$2"
    if echo "$BACKUPS" | grep -q "$db"; then
        echo "  [OK]   $engine/$db"
        PASS=$((PASS + 1))
    else
        echo "  [MISS] $engine/$db — no backup found in /databasus-data/backups"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "==> PostgreSQL"
for db in $PG_DBS; do
    check_db postgres "$db"
done

echo ""
echo "==> MySQL"
for db in $MYSQL_DBS; do
    check_db mysql "$db"
done

echo ""
if [[ $FAIL -gt 0 ]]; then
    echo "FAIL: $PASS backed up, $FAIL missing"
    exit 1
else
    echo "OK: all $PASS databases have backups"
fi
