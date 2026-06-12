#!/usr/bin/env bash
# bother-dev-cmdline.sh — print a command line for running a local dev build
# of nomad-botherer outside docker, with the same environment as the version
# currently deployed on the cluster.
#
# Reads the env template from the running job spec (nomad inspect) and
# renders its nomadVar lookups, so the output always matches what the
# deployed task sees — even if the job file changes.
#
# WARNING: the output contains secrets (webhook secret, API key, Nomad
# token). Don't paste it anywhere public.
#
# Usage: bother-dev-cmdline.sh [path-to-binary]   (default: ./nomad-botherer)
#
# Requires: nomad (with cluster access and NOMAD_TOKEN), jq

set -euo pipefail

BINARY="${1:-./nomad-botherer}"
JOB="nomad-botherer"

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

tmpl=$(nomad inspect "$JOB" \
  | jq -r --arg t "$JOB" '.Job.TaskGroups[].Tasks[] | select(.Name == $t)
      | .Templates[] | select(.Envvars == true) | .EmbeddedTmpl')
[[ -n "$tmpl" ]] || { echo "error: no env template found in running job ${JOB}" >&2; exit 1; }

declare -A var_cache
cmd="env"
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  key=${line%%=*}
  val=${line#*=}
  # Render {{ with nomadVar "<path>" }}{{ .<item> }}{{ end }} lookups.
  if [[ $val == *nomadVar* ]]; then
    var_path=$(sed -n 's/.*nomadVar "\([^"]*\)".*/\1/p' <<<"$val")
    item=$(sed -n 's/.*{{ \.\([A-Za-z0-9_]*\) }}.*/\1/p' <<<"$val")
    [[ -n "$var_path" && -n "$item" ]] \
      || { echo "error: cannot parse template line: $line" >&2; exit 1; }
    if [[ ! -v var_cache[$var_path] ]]; then
      var_cache[$var_path]=$(nomad var get -out=json "$var_path") \
        || { echo "error: cannot read ${var_path} — is NOMAD_TOKEN set?" >&2; exit 1; }
    fi
    val=$(jq -re --arg k "$item" '.Items[$k]' <<<"${var_cache[$var_path]}") \
      || { echo "error: item ${item} not found in ${var_path}" >&2; exit 1; }
  fi
  cmd+=" $(printf '%q' "${key}=${val}")"
done <<<"$tmpl"

echo "$cmd $(printf '%q' "$BINARY")"
