#!/usr/bin/env bash
# nomad-diff.sh — diff all Nomad job files in the repo against the running cluster.
#
# Uses `nomad job plan` (dry-run scheduler) which exits:
#   0   → no changes
#   1   → changes (allocations would be created/destroyed/updated)
#   255 → error (job not found on cluster, auth failure, etc.)
#
# Requires: NOMAD_TOKEN set in environment
# Optional: NOMAD_ADDR (default: http://127.0.0.1:4646)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOMAD_DIR="${REPO_ROOT}/nomad"

if [[ -z "${NOMAD_TOKEN:-}" ]]; then
    echo "ERROR: NOMAD_TOKEN is not set" >&2
    exit 1
fi

CHANGED=()
UNCHANGED=()
ERRORS=()

echo "Diffing Nomad jobs against cluster (${NOMAD_ADDR:-http://127.0.0.1:4646})"
echo ""

# Find all HCL files that are actual Nomad jobs (have a top-level `job "` stanza).
# This excludes ACL policy files and CSI volume definitions.
while IFS= read -r jobfile; do
    rel="${jobfile#"${REPO_ROOT}/"}"

    set +e
    output=$(nomad job plan "$jobfile" 2>&1)
    exitcode=$?
    set -e

    case $exitcode in
        0)
            printf "  %-10s %s\n" "OK" "$rel"
            UNCHANGED+=("$rel")
            ;;
        1)
            printf "  %-10s %s\n" "CHANGED" "$rel"
            echo ""
            echo "$output"
            echo ""
            CHANGED+=("$rel")
            ;;
        255)
            printf "  %-10s %s\n" "ERROR" "$rel"
            echo ""
            echo "$output"
            echo ""
            ERRORS+=("$rel")
            ;;
        *)
            printf "  %-10s %s (exit %d)\n" "UNKNOWN" "$rel" "$exitcode"
            echo "$output"
            ERRORS+=("$rel")
            ;;
    esac
done < <(grep -rl '^job "' "$NOMAD_DIR" --include='*.hcl')

echo ""
echo "=== Summary ==="
printf "  Unchanged : %d\n" "${#UNCHANGED[@]}"
printf "  Changed   : %d\n" "${#CHANGED[@]}"
printf "  Errors    : %d\n" "${#ERRORS[@]}"

if [[ ${#CHANGED[@]} -gt 0 ]]; then
    echo ""
    echo "Jobs with pending changes:"
    for j in "${CHANGED[@]}"; do
        echo "  - $j"
    done
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "Jobs with errors:"
    for j in "${ERRORS[@]}"; do
        echo "  - $j"
    done
fi

echo ""

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    exit 2
elif [[ ${#CHANGED[@]} -gt 0 ]]; then
    exit 1
else
    exit 0
fi
