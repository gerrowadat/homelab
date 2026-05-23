# nomad/monitoring

Prometheus-based monitoring stack with Grafana dashboards.

| Job | What it is |
|---|---|
| `prometheus` | Metrics collection and alerting |
| `prom-alertmanager` | Alert routing (email notifications) |
| `prom-blackbox-exporter` | HTTP and ICMP probes |
| `prom-consul-exporter` | Consul cluster metrics |
| `grafana` | Dashboards and visualisation at `home.andvari.net/graphs` |
| `victorialogs` | Centralised log storage (VictoriaLogs), queryable at `logs.home.andvari.net` |
| `otel-collector` | OTEL Collector system job (one per node); tails Docker logs and accepts OTLP push |

See `docs/log-collection.md` for the full rollout guide and operational playbook.

Key log commands:

```bash
# Check both jobs
nomad job status victorialogs
nomad job status otel-collector

# Health check
curl -s http://logs.service.home.consul:9428/health

# Query recent logs
curl -s 'http://logs.service.home.consul:9428/select/logsql/query?query=*&limit=10' | jq .

# Check storage usage
curl -s http://logs.service.home.consul:9428/metrics | grep victorialogs_data_size_bytes
```

Prometheus config files (scrape targets, alert rules, recording rules) live in
`monitoring/` at the repo root — mounted into the prometheus container via the
`gitrepo` CSI volume. A Nomad template combines `prometheus.yml` with Grafana
Cloud `remote_read` credentials at task startup into `/local/prometheus.yml`.
Alert rule changes (via the `*_rules.yml` glob) are picked up by `/-/reload`
without a redeploy; scrape config changes in `prometheus.yml` require one.

Grafana provisioning config (datasources, dashboard providers, dashboard JSON
files) lives in `monitoring/grafana/` — also mounted via the `gitrepo` CSI
volume. See `docs/grafana.md` for the full setup guide and playbook.

To reload Prometheus config without restarting the container:

```bash
bash scripts/reload_prometheus.sh
bash scripts/reload_prometheus_blackbox.sh  # for blackbox exporter
```

To reload Grafana provisioning (datasources + dashboards) without restarting:

```bash
# Requires admin credentials
curl -s -X POST -u admin:PASSWORD \
  http://grafana.service.home.consul:3000/api/admin/provisioning/datasources/reload
curl -s -X POST -u admin:PASSWORD \
  http://grafana.service.home.consul:3000/api/admin/provisioning/dashboards/reload
```

Grafana also polls `monitoring/grafana/dashboards/` every 30 seconds for
updated dashboard JSON files, so dashboard changes propagate automatically
without needing a webhook push.
