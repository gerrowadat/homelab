#!/usr/bin/env bash
# Update a single key in a Nomad variable, preserving all other keys.
# Usage: nomad-var-set.sh <variable-path> <key> <value>
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $(basename "$0") <variable-path> <key> <value>" >&2
  echo "Example: $(basename "$0") nomad/jobs/postgres pgpassword s3cr3t" >&2
  exit 1
fi

path="$1"
key="$2"
value="$3"

nomad var get -out json "$path" \
  | jq --arg k "$key" --arg v "$value" '.Items[$k] = $v' \
  | nomad var put -in json "$path" -
