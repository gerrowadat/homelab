# monitoring

Prometheus configuration files, bind-mounted into the prometheus container by
the Nomad job in `nomad/monitoring/prometheus.hcl`.

| File | Purpose |
|---|---|
| `prometheus.yml` | Main config: scrape jobs, alertmanager address, rule files |
| `node_exporter_alerting_rules.yml` | Alerts for host-level metrics (disk, memory, load) |
| `node_exporter_recording_rules.yml` | Pre-computed recording rules for dashboard performance |
| `blackbox_alerting_rules.yml` | Alerts for failed HTTP/ICMP probes |
| `prom-alertmanager.yml` | Alert routing and email notification config |
| `prom-blackbox-exporter.yml` | Probe module definitions (http_2xx, icmp) |

## Reloading config

Prometheus and the blackbox exporter both support live config reload via HTTP:

```bash
bash reload_prometheus.sh
bash reload_prometheus_blackbox.sh
```
