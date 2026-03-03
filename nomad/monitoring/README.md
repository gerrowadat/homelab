# nomad/monitoring

Prometheus-based monitoring stack.

| Job | What it is |
|---|---|
| `prometheus` | Metrics collection and alerting |

| `prom-alertmanager` | Alert routing (email notifications) |
| `prom-blackbox-exporter` | HTTP and ICMP probes |
| `prom-consul-exporter` | Consul cluster metrics |

Prometheus config files (scrape targets, alert rules, recording rules) live in
`monitoring/` at the repo root — they're bind-mounted into the prometheus container.

To reload Prometheus config without restarting the container:

```bash
bash monitoring/reload_prometheus.sh
bash monitoring/reload_prometheus_blackbox.sh  # for blackbox exporter
```
