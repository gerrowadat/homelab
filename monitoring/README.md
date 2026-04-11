# monitoring

Prometheus configuration files, mounted into the prometheus container via the
`gitrepo` CSI volume by the Nomad job in `nomad/monitoring/prometheus.hcl`.

| File / Directory | Purpose |
|---|---|
| `prometheus.yml` | Main config: scrape jobs, alertmanager address, rule files |
| `node_exporter_alerting_rules.yml` | Alerts for host-level metrics (disk, memory, load) |
| `node_exporter_recording_rules.yml` | Pre-computed recording rules for dashboard performance |
| `blackbox_alerting_rules.yml` | Alerts for failed HTTP/ICMP probes |
| `paperless_alerting_rules.yml` | Alerts for paperless-ngx (Traefik 5xx error rate) |
| `prom-alertmanager.yml` | Alert routing and email notification config |
| `prom-blackbox-exporter.yml` | Probe module definitions (http_2xx, icmp) |
| `grafana/` | Grafana provisioning config and dashboard JSON files |
| `grafana/provisioning/datasources/` | Datasource definitions (Prometheus pre-configured) |
| `grafana/provisioning/dashboards/` | Dashboard provider config |
| `grafana/dashboards/` | Dashboard JSON files — add `.json` exports here |

See `docs/grafana.md` for the Grafana setup guide and playbook.

## Config reload workflow

Config changes are applied by pushing to `main`. A GitHub webhook triggers
`homelab-webhook` (a Nomad service job at `nomad/infra/homelab-webhook/`),
which pulls the latest git repo onto the `gitrepo` CSI volume.

```
git push → GitHub webhook → home.andvari.net/webhooks/monitoring-reload (Traefik)
  → homelab-webhook Nomad job → git pull on CSI volume
  → if monitoring/ changed (excl. grafana/):
      POST /-/reload to prometheus, alertmanager, blackbox-exporter
  → if monitoring/grafana/ changed:
      POST /api/admin/provisioning/datasources/reload to Grafana
      POST /api/admin/provisioning/dashboards/reload to Grafana
```

Grafana also polls `monitoring/grafana/dashboards/` every 30 seconds, so
dashboard JSON changes propagate even without a webhook push.

## Validating configs before pushing

Run the local check script before pushing to catch config errors early:

```bash
bash scripts/check-monitoring-configs.sh
```

This runs the same Docker-based checks as CI (promtool, amtool,
blackbox-exporter `--config.check`). Requires Docker.

CI also runs these checks automatically on PRs and pushes to `main` that
touch `monitoring/**` (`.github/workflows/monitoring-validate.yml`).

## Setup

### 1. Create the webhook secret in Nomad

```bash
nomad var put nomad/jobs/homelab-webhook \
  github_webhook_secret="<random-secret>"
```

### 2. Deploy the webhook receiver

```bash
nomad run nomad/infra/homelab-webhook/homelab-webhook.hcl
```

### 3. Configure the GitHub webhook

In the repo Settings → Webhooks → Add webhook:

- **Payload URL:** `https://home.andvari.net/webhooks/monitoring-reload`
- **Content type:** `application/json`
- **Secret:** the same random secret from step 1
- **Events:** Just the push event

### 4. Stop the polling cron jobs

Once the webhook receiver is running, the old polling jobs are redundant:

```bash
nomad job stop pull-gitrepo
nomad job stop git-pull-homelab
```

## Verification

1. Run `bash scripts/check-monitoring-configs.sh` — should exit 0
2. Introduce a YAML syntax error, re-run — should exit non-zero
3. Open a PR touching `monitoring/` — GH Actions should show pass/fail
4. After deploying and configuring the webhook, push a config change to main —
   the GitHub webhook deliveries tab should show a 200 response, and
   prometheus/alertmanager/blackbox should reflect the change immediately
