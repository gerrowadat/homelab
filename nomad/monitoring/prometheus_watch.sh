#!/bin/sh
# Prometheus supervisor script. Runs inside the prom/prometheus container.
#
# Starts prometheus as a background process and watches for config changes:
#   - SIGHUP (sent by Nomad when remote_read.yml changes via credential
#     rotation) triggers an immediate re-concatenate + reload.
#   - Polling loop detects changes to prometheus.yml from the gitrepo
#     (updated by the homelab-webhook on push to main) and reloads.
#
# Paths:
#   /config/monitoring/prometheus.yml  -- gitrepo CSI volume (read-only)
#   /local/remote_read.yml             -- Nomad-rendered Grafana Cloud creds
#   /local/prometheus.yml              -- combined config, read by prometheus

cat /config/monitoring/prometheus.yml /local/remote_read.yml > /local/prometheus.yml

/bin/prometheus \
  --config.file=/local/prometheus.yml \
  --storage.tsdb.path=/data/prometheus/prom-tsdb/ \
  --web.external-url=http://prometheus.service.home.consul:9090/ \
  --web.enable-lifecycle &
PROM_PID=$!

reload() {
  echo "Reloading prometheus..."
  cat /config/monitoring/prometheus.yml /local/remote_read.yml > /local/prometheus.yml
  kill -HUP "$PROM_PID"
}
trap reload HUP
trap 'kill "$PROM_PID"; wait "$PROM_PID"' TERM INT

LAST_HASH=$(md5sum /config/monitoring/prometheus.yml | cut -d' ' -f1)
while kill -0 "$PROM_PID" 2>/dev/null; do
  sleep 10
  HASH=$(md5sum /config/monitoring/prometheus.yml | cut -d' ' -f1)
  if [ "$HASH" != "$LAST_HASH" ]; then
    echo "prometheus.yml changed, reloading..."
    reload
    LAST_HASH="$HASH"
  fi
done

wait "$PROM_PID"
