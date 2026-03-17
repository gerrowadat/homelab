#!/usr/bin/env bash
# pg-connect.sh — retrieve the postgres admin password from Nomad and open a psql shell.
#
# Fetches the password from the Nomad variable at nomad/jobs/postgres and connects
# to postgres.service.home.consul as the postgres superuser.
#
# Requires: nomad CLI, psql, jq
# Requires: NOMAD_TOKEN set in environment
# Optional: NOMAD_ADDR (default: http://127.0.0.1:4646)
set -euo pipefail

if [[ -z "${NOMAD_TOKEN:-}" ]]; then
    echo "ERROR: NOMAD_TOKEN is not set" >&2
    exit 1
fi

PGPASSWORD=$(nomad var get -out=json nomad/jobs/postgres | jq -r '.Items.pgpassword')
export PGPASSWORD

exec psql -h postgres.service.home.consul -U postgres "$@"
