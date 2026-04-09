#!/usr/bin/env bash
# volume-shell.sh — start an interactive shell with a Nomad CSI volume mounted.
#
# Usage: volume-shell.sh <volume-name>
#
# Runs a temporary Nomad job that mounts the specified volume at /<volume-name>,
# then attaches an interactive shell. The job is stopped and purged on exit.
#
# Requires: nomad CLI
# Requires: NOMAD_TOKEN set in environment (or nomad CLI configured with ACL token)
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <volume-name>" >&2
    exit 1
fi

VOLUME_NAME="$1"
JOB_NAME="volume-shell-${VOLUME_NAME}"

cleanup() {
    echo "Stopping job ${JOB_NAME}..."
    nomad job stop -purge "${JOB_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

# Create temporary job spec
JOB_SPEC=$(mktemp)
cat > "${JOB_SPEC}" <<EOF
job "${JOB_NAME}" {
  datacenters = ["home"]
  type        = "batch"

  group "shell" {
    volume "${VOLUME_NAME}" {
      type            = "csi"
      source          = "${VOLUME_NAME}"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    task "shell" {
      driver = "docker"

      config {
        image   = "alpine:latest"
        command = "/bin/sh"
        args    = ["-c", "echo 'Volume mounted at /${VOLUME_NAME}. Press Ctrl+D or type exit to quit.' && sleep infinity"]
        interactive = true
        tty         = true
      }

      volume_mount {
        volume      = "${VOLUME_NAME}"
        destination = "/${VOLUME_NAME}"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
EOF

echo "Starting job ${JOB_NAME} with volume ${VOLUME_NAME}..."
nomad job run "${JOB_SPEC}"
rm -f "${JOB_SPEC}"

# Wait for allocation to be running
echo "Waiting for allocation to start..."
for i in {1..30}; do
    ALLOC_ID=$(nomad job allocs -t '{{range .}}{{if eq .ClientStatus "running"}}{{.ID}}{{end}}{{end}}' "${JOB_NAME}" 2>/dev/null || true)
    if [[ -n "${ALLOC_ID}" ]]; then
        break
    fi
    sleep 1
done

if [[ -z "${ALLOC_ID}" ]]; then
    echo "ERROR: Allocation did not start within 30 seconds" >&2
    nomad job status "${JOB_NAME}"
    exit 1
fi

echo "Attaching to allocation ${ALLOC_ID}..."
echo "Volume is mounted at /${VOLUME_NAME}"
echo "---"

nomad alloc exec -i -t "${ALLOC_ID}" /bin/sh
