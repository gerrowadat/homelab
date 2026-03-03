#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MONITORING_DIR="${REPO_ROOT}/monitoring"

echo "==> Checking monitoring configs in ${MONITORING_DIR}"

echo ""
echo "--- prometheus config ---"
docker run --rm \
  --entrypoint promtool \
  -v "${MONITORING_DIR}:/monitoring:ro" \
  prom/prometheus:v3.10.0 \
  check config /monitoring/prometheus.yml
echo "PASS: prometheus config"

echo ""
echo "--- alertmanager config ---"
docker run --rm \
  --entrypoint /bin/amtool \
  -v "${MONITORING_DIR}:/monitoring:ro" \
  prom/alertmanager \
  check-config /monitoring/prom-alertmanager.yml
echo "PASS: alertmanager config"

echo ""
echo "--- blackbox-exporter config ---"
docker run --rm \
  -v "${MONITORING_DIR}:/monitoring:ro" \
  prom/blackbox-exporter \
  --config.file=/monitoring/prom-blackbox-exporter.yml \
  --config.check
echo "PASS: blackbox-exporter config"

echo ""
echo "All configs OK."
