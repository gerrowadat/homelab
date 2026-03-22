# scripts

Utility scripts for operating the homelab cluster.

| Script | Purpose |
|---|---|
| `check-monitoring-configs.sh` | Validate Prometheus, Alertmanager, and Blackbox Exporter configs locally (uses Docker). Run before pushing changes to `monitoring/`. CI runs the same checks. |
| `reload_prometheus.sh` | POST `/-/reload` to Prometheus via its Consul address. |
| `reload_prometheus_blackbox.sh` | POST `/-/reload` to the Blackbox Exporter via its Consul address. |
| `nomad-diff.sh` | Show a diff of what would change if a Nomad job file were submitted (dry-run helper). |
| `pg-connect.sh` | Open a psql session to the local postgres instance via its Consul address. |
| `mysql-connect.sh` | Open a mysql shell to the local mysql instance via its Consul address. |
| `grafana-sm-export-tfvars.py` | Reconstruct `terraform/grafana-sm/terraform.tfvars` from the live Grafana Cloud Synthetic Monitoring API. Run this if you've lost your local tfvars. See `docs/grafana-synthetic-monitoring.md`. |

## Monitoring validation

Always run before pushing changes to `monitoring/`:

```bash
bash scripts/check-monitoring-configs.sh
```

This validates `prometheus.yml`, all `*.rules.yml` / alerting rule files,
and `blackbox.yml` using the same Docker images as CI.
