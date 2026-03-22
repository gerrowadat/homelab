# nomad/monitoring

Prometheus-based monitoring stack with Grafana dashboards.

| Job | What it is |
|---|---|
| `prometheus` | Metrics collection and alerting |
| `prom-alertmanager` | Alert routing (email notifications) |
| `prom-blackbox-exporter` | HTTP and ICMP probes |
| `prom-consul-exporter` | Consul cluster metrics |
| `grafana` | Dashboards and visualisation at `home.andvari.net/graphs` |
| `grafana-alloy` | Federates Grafana Cloud SM metrics into local Prometheus via remote_write |

Prometheus config files (scrape targets, alert rules, recording rules) live in
`monitoring/` at the repo root — mounted into the prometheus container via the
`gitrepo` CSI volume.

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
