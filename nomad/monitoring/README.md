# nomad/monitoring

Prometheus-based monitoring stack.

| Job | What it is |
|---|---|
| `prometheus` | Metrics collection and alerting |
| `prom-alertmanager` | Alert routing (email notifications) |
| `prom-blackbox-exporter` | HTTP and ICMP probes |
| `prom-consul-exporter` | Consul cluster metrics |

Prometheus config files (scrape targets, alert rules, recording rules) live in
`monitoring/` at the repo root — mounted into the prometheus container via the
`gitrepo` CSI volume.

To reload Prometheus config without restarting the container:

```bash
bash scripts/reload_prometheus.sh
bash scripts/reload_prometheus_blackbox.sh  # for blackbox exporter
```
