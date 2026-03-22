# Grafana Cloud Synthetic Monitoring

Grafana Cloud's synthetic monitoring runs HTTP checks from public probe locations worldwide.
This lets you verify that homelab-hosted URLs are (or are not) reachable from the public internet,
with results feeding into the existing Prometheus alerting stack.

## Architecture

```
Grafana Cloud
  ├── Public probes (regional locations)
  │     └── run checks defined in terraform/grafana-sm/
  └── Metrics backend (Grafana Cloud hosted Prometheus / Mimir)
        ↑ results written here by probes

Local Prometheus
  ├── remote_read → Grafana Cloud metrics API (credentials in nomad/jobs/prometheus)
  │     └── fetches probe_* metrics on demand during rule evaluation
  └── evaluates grafana-sm-alerting-rules.yml → Alertmanager → you
```

The `remote_read` section is injected into the running Prometheus config at startup via
Nomad template — it is not present in the committed `prometheus.yml` so that account
identifiers stay out of git. Alert rule files (`monitoring/*.yml`) still load from the
gitrepo and are picked up by `/-/reload` as normal.

**Note:** Changes to `prometheus.yml` scrape targets require `nomad job run
nomad/monitoring/prometheus.hcl` to take effect (not just `/-/reload`), because
Prometheus runs against the template-generated combined config.

## One-time setup

### 1. Create a Grafana Cloud account

Sign up at grafana.com/auth/sign-up. The free tier includes synthetic monitoring.
During signup, you'll create an **organisation** and a **stack** (a hosted Grafana+Prometheus instance).

### 2. Enable Synthetic Monitoring

In your Grafana Cloud instance:
- Go to **Home → Synthetic Monitoring → Get started**
- Follow the initialisation wizard — it provisions the SM plugin and creates the metrics data source.

### 3. Collect the values you'll need

**`grafana_cloud_url`**
Your Grafana Cloud instance URL. Format: `https://<your-org>.grafana.net`

**`grafana_api_key`**
A service account token with Editor or Admin role.
- **Administration → Users and access → Service accounts → Add service account**
- Add a token to that service account. Copy it — you won't see it again.

**`sm_access_token`**
A Synthetic Monitoring-specific token.
- In your Grafana Cloud instance: **Synthetic Monitoring → Config → API Tokens → Generate token**
- Choose "MetricsPublisher" or equivalent. Copy it.

**`sm_url`**
The SM API endpoint for your region.
- In your Grafana Cloud instance: **Synthetic Monitoring → Config**
- It's shown as the "Backend address". Usually `https://synthetic-monitoring-api.grafana.net`.

**`grafana_metrics_host`**
The hostname of your Grafana Cloud Prometheus instance — no `https://`, no path.
- In Grafana Cloud: **Connections → Data sources → grafanacloud-\<org\>-prom → Settings**
- The URL field contains something like `https://prometheus-prod-01-prod-us-east-0.grafana.net`
- Extract just the hostname: `prometheus-prod-01-prod-us-east-0.grafana.net`

**`grafana_stack_id`**
Your numeric stack ID, used as the basic auth username for the metrics API.
- Found on the same Connections → Data sources screen, in the "User" field.
- It's a number, e.g. `123456`.

**`grafana_metrics_read_token`**
A Cloud Access Policy token with `metrics:read` scope. This is separate from the service
account token — it's used to authenticate the Prometheus remote_read against Grafana Cloud Mimir.
- Go to **grafana.com → top-right account menu → My Account → Security → Access Policies**
- Create an access policy with `metrics:read` scope for your stack
- Generate a token and copy it.

### 4. Configure and apply Terraform

```bash
cd terraform/grafana-sm
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — fill in all values and define your checks.
# See the example file for check structure and comments.

terraform init
terraform plan
terraform apply
```

`terraform.tfvars` is gitignored. Do not commit it.

If `terraform plan` shows probe names that don't exist, run:

```bash
terraform console
> data.grafana_synthetic_monitoring_probes.available.probes
```

to see available probe names for your account, then update `terraform.tfvars` accordingly.

### 5. Create the Nomad variables

Two Nomad variables are used. `nomad/jobs/grafana-cloud` holds credentials for managing
and exporting checks. `nomad/jobs/prometheus` holds credentials for metrics read access.

**`nomad/jobs/grafana-cloud`** — SM API credentials and export script source of truth:

```bash
nomad var put nomad/jobs/grafana-cloud \
  grafana_cloud_url="https://yourorg.grafana.net" \
  grafana_api_key="glsa_xxxxxxxxxxxx" \
  sm_access_token="eyJrIjoixxxxxxxx" \
  sm_url="https://synthetic-monitoring-api.grafana.net"
```

**`nomad/jobs/prometheus`** — metrics read credentials for remote_read:

```bash
nomad var put nomad/jobs/prometheus \
  grafana_metrics_host="prometheus-prod-01-prod-us-east-0.grafana.net" \
  grafana_stack_id="123456" \
  grafana_metrics_read_token="<cloud-access-policy-token>"
```

### 6. Deploy the updated Prometheus job

The Prometheus job now generates its config at startup by combining the gitrepo
`prometheus.yml` with a `remote_read` section built from `nomad/jobs/prometheus`.

```bash
nomad job run nomad/monitoring/prometheus.hcl
```

### 7. Verify in Prometheus

After Prometheus starts, query in the Prometheus UI (remote_read is on-demand so no
waiting for a scrape interval):

```
probe_success{source="grafana-sm"}
```

You should see one series per probe per check.

## Recovering a lost terraform.tfvars

`terraform.tfvars` is gitignored and contains all your secrets and check definitions.
If you lose it, reconstruct it from the live SM API using the credentials in the Nomad variable:

```bash
python3 scripts/grafana-sm-export-tfvars.py
```

This reads `nomad/jobs/grafana-cloud`, queries the SM API for the current probe list and
check list, and writes `terraform/grafana-sm/terraform.tfvars`. If the file already exists,
pass `--force` to overwrite it. You can also specify a different output path with `-o`.

After recovery, verify it round-trips cleanly:

```bash
terraform -chdir=terraform/grafana-sm plan
```

A clean plan (no changes) means the recovered file matches what's deployed.

## Adding or modifying checks

Edit `terraform/grafana-sm/terraform.tfvars` and add entries to the `http_checks` map.
Then run `terraform apply`. No Nomad job changes needed.

## Alert logic

Two alert rules are defined in `monitoring/grafana-sm-alerting-rules.yml`:

| Alert | Condition | Fires when |
|---|---|---|
| `SyntheticCheckDown` | `alert_if_up = false` | All probes fail for 5m — public endpoint is down |
| `InternalEndpointExposed` | `alert_if_up = true` | Any probe succeeds for 5m — internal endpoint is reachable from internet |

`SyntheticCheckDown` uses `min()` across probes: a single flaky probe location does not page.
`InternalEndpointExposed` uses `max()`: any successful probe is a problem.

## Probe locations (free tier)

The free tier provides access to a subset of Grafana's public probe network.
To see exactly which probes are available to your account, run in the Terraform directory:

```bash
terraform console
> data.grafana_synthetic_monitoring_probes.available.probes
```

Probe names used in `terraform.tfvars` must match these exactly (case-sensitive).
