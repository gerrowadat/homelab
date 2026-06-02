#!/usr/bin/env bash
# bother.sh — CLI wrapper for the nomad-botherer JSON API.
#
# Reads the API key from the Nomad variable at nomad/jobs/nomad-botherer and
# calls the nomad-botherer HTTP API. Authenticated endpoints require
# NOMAD_TOKEN to be set so the key can be fetched.
#
# Usage: bother.sh <command>
#
# Requires: nomad, curl, jq
# Optional: NOMAD_ADDR, NOMAD_TOKEN, NOMAD_BOTHERER_ADDR

set -euo pipefail

BOTHERER_ADDR="${NOMAD_BOTHERER_ADDR:-http://nomad-botherer.service.home.consul:9112}"
VAR_PATH="nomad/jobs/nomad-botherer"

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") <command>

Authenticated commands (require NOMAD_TOKEN):
  diffs           Current job drift report
  selected-jobs   Jobs being watched and why they matched
  status          Git watcher status (last commit, last fetch time)
  version         Build version and commit hash
  refresh         Trigger an immediate git pull + diff check

Unauthenticated commands:
  healthz         Health check + drift summary
  metrics         Prometheus metrics
  spec            OpenAPI 3.0 specification (JSON)

Environment:
  NOMAD_TOKEN           Nomad ACL token (required for authenticated commands)
  NOMAD_ADDR            Nomad API address (default: http://127.0.0.1:4646)
  NOMAD_BOTHERER_ADDR   Override the botherer address
                        (default: http://nomad-botherer.service.home.consul:9112)
EOF
    exit 1
}

get_api_key() {
    [[ -n "${NOMAD_TOKEN:-}" ]] || die "NOMAD_TOKEN is not set"
    local key
    key=$(nomad var get -out=json "$VAR_PATH" 2>/dev/null \
        | jq -r '.Items.github_webhook_secret' 2>/dev/null || true)
    [[ -n "$key" && "$key" != "null" ]] \
        || die "could not read github_webhook_secret from ${VAR_PATH} — check NOMAD_TOKEN"
    printf '%s' "$key"
}

bother_get() {
    curl -sf \
        -H "Authorization: Bearer $1" \
        "${BOTHERER_ADDR}$2" \
      | jq .
}

bother_post() {
    curl -sf -X POST \
        -H "Authorization: Bearer $1" \
        "${BOTHERER_ADDR}$2" \
      | jq .
}

bother_anon() {
    curl -sf "${BOTHERER_ADDR}$1"
}

[[ $# -ge 1 ]] || usage
CMD="$1"; shift

case "$CMD" in
    diffs)          bother_get "$(get_api_key)" /api/v1/diffs ;;
    selected-jobs)  bother_get "$(get_api_key)" /api/v1/selected-jobs ;;
    status)         bother_get "$(get_api_key)" /api/v1/status ;;
    version)        bother_get "$(get_api_key)" /api/v1/version ;;
    refresh)        bother_post "$(get_api_key)" /api/v1/refresh ;;
    healthz)        bother_anon /healthz | jq . ;;
    metrics)        bother_anon /metrics ;;
    spec)           bother_anon /api/openapi.json | jq . ;;
    -h|--help|help) usage ;;
    *)              echo "Unknown command: ${CMD}" >&2; usage ;;
esac
