#!/bin/sh
# Concatenate the gitrepo prometheus.yml with the Nomad-rendered remote_read
# credentials, then exec prometheus as PID 1.
#
# Paths:
#   /config/monitoring/prometheus.yml  -- gitrepo CSI volume (scrape config, rules glob)
#   /local/remote_read.yml             -- Nomad-rendered Grafana Cloud credentials
#   /local/prometheus.yml              -- combined config read by prometheus
set -eu
cat /config/monitoring/prometheus.yml /local/remote_read.yml > /local/prometheus.yml
exec /bin/prometheus \
  --config.file=/local/prometheus.yml \
  --storage.tsdb.path=/data/prometheus/prom-tsdb/ \
  --web.external-url=http://prometheus.service.home.consul:9090/ \
  --web.enable-lifecycle
