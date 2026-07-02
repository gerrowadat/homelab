#!/usr/bin/env bash
# gitops.sh — CLI wrapper for the nomad-gitops JSON API.
#
# Reads the API key from the Nomad variable at nomad/jobs/nomad-gitops and
# calls the nomad-gitops HTTP API. Authenticated endpoints require
# NOMAD_TOKEN to be set so the key can be fetched.
#
# Usage: gitops.sh <command>
#
# Requires: nomad, curl, jq
# Optional: NOMAD_ADDR, NOMAD_TOKEN, NOMAD_GITOPS_ADDR

set -euo pipefail

GITOPS_ADDR="${NOMAD_GITOPS_ADDR:-http://nomad-gitops.service.home.consul:9112}"
VAR_PATH="nomad/jobs/nomad-gitops"

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
  NOMAD_GITOPS_ADDR   Override the gitops address
                        (default: http://nomad-gitops.service.home.consul:9112)
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

gitops_get() {
    curl -sf \
        -H "Authorization: Bearer $1" \
        "${GITOPS_ADDR}$2" \
      | jq .
}

gitops_post() {
    curl -sf -X POST \
        -H "Authorization: Bearer $1" \
        "${GITOPS_ADDR}$2" \
      | jq .
}

gitops_anon() {
    curl -sf "${GITOPS_ADDR}$1"
}

[[ $# -ge 1 ]] || usage
CMD="$1"; shift

case "$CMD" in
    diffs)          gitops_get "$(get_api_key)" /api/v1/diffs ;;
    selected-jobs)  gitops_get "$(get_api_key)" /api/v1/selected-jobs ;;
    status)         gitops_get "$(get_api_key)" /api/v1/status ;;
    version)        gitops_get "$(get_api_key)" /api/v1/version ;;
    refresh)        gitops_post "$(get_api_key)" /api/v1/refresh ;;
    healthz)        gitops_anon /healthz | jq . ;;
    metrics)        gitops_anon /metrics ;;
    spec)           gitops_anon /api/openapi.json | jq . ;;
    -h|--help|help) usage ;;
    *)              echo "Unknown command: ${CMD}" >&2; usage ;;
esac
