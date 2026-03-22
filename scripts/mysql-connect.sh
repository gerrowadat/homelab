#!/usr/bin/env bash
# mysql-connect.sh — retrieve the mysql root password from Nomad and open a mysql shell.
#
# Fetches the password from the Nomad variable at nomad/jobs/mysql and connects
# to mysql.service.home.consul as root.
#
# Requires: nomad CLI, mysql, jq
# Requires: NOMAD_TOKEN set in environment
# Optional: NOMAD_ADDR (default: http://127.0.0.1:4646)
set -euo pipefail

if [[ -z "${NOMAD_TOKEN:-}" ]]; then
    echo "ERROR: NOMAD_TOKEN is not set" >&2
    exit 1
fi

MYSQL_PWD=$(nomad var get -out=json nomad/jobs/mysql | jq -r '.Items.root_password')
export MYSQL_PWD

exec mysql -h mysql.service.home.consul -u root "$@"
