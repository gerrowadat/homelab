#!/bin/sh
# Watches prometheus.yml (gitrepo) and remote_read.yml (Nomad-rendered) for
# changes. Re-concatenates both into /alloc/prometheus.yml and calls /-/reload
# so all config changes are picked up without a nomad job run.
#
# Runs as a poststart sidecar in the prometheus task group. Tasks share the
# allocation directory (/alloc/) and network namespace (localhost:9090).

# Wait for prometheus to be ready before the initial sync.
sleep 10
cat /config/monitoring/prometheus.yml /alloc/remote_read.yml > /alloc/prometheus.yml
wget -q --post-data='' -O- http://localhost:9090/-/reload || true

LAST_HASH=$(md5sum /config/monitoring/prometheus.yml /alloc/remote_read.yml | md5sum | cut -d' ' -f1)
while true; do
  sleep 10
  HASH=$(md5sum /config/monitoring/prometheus.yml /alloc/remote_read.yml | md5sum | cut -d' ' -f1)
  if [ "$HASH" != "$LAST_HASH" ]; then
    echo "Config changed, reloading prometheus..."
    cat /config/monitoring/prometheus.yml /alloc/remote_read.yml > /alloc/prometheus.yml
    wget -q --post-data='' -O- http://localhost:9090/-/reload
    LAST_HASH="$HASH"
  fi
done
