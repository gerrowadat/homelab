# Grafana Cloud Synthetic Monitoring

Grafana Cloud's synthetic monitoring runs HTTP checks from public probe locations worldwide.
This lets you verify that homelab-hosted URLs are (or are not) reachable from the public internet,
with results feeding into the existing Prometheus alerting stack.

## Architecture

```
Grafana Cloud
  ├── Public probes (Atlanta, London, Singapore, …)
  │     └── run checks defined in terraform/grafana-sm/
  └── Metrics backend (Grafana Cloud hosted Prometheus)
        ↑ results written here by probes

grafana-alloy (Nomad job)
  └── federates probe_* metrics from Grafana Cloud → remote_write → local Prometheus

Local Prometheus
  └── evaluates grafana-sm-alerting-rules.yml → Alertmanager → you
```

## One-time setup

### 1. Create a Grafana Cloud account

Sign up at grafana.com/auth/sign-up. The free tier includes synthetic monitoring.
During signup, you'll create an **organisation** and a **stack** (a hosted Grafana+Prometheus instance).

### 2. Enable Synthetic Monitoring

In your Grafana Cloud instance:
- Go to **Home → Synthetic Monitoring → Get started**
- Follow the initialisation wizard — it provisions the SM plugin and creates the metrics data source.

### 3. Collect the values you'll need

You need four values. Find them as follows:

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

**`grafana_metrics_host`** (for the Nomad variable — see section 5)
The hostname of your Grafana Cloud Prometheus instance — no `https://`, no path.
- In Grafana Cloud: **Connections → Data sources → grafanacloud-<org>-prom → Settings**
- The URL field contains something like `https://prometheus-prod-01-prod-us-east-0.grafana.net`
- Extract just the hostname: `prometheus-prod-01-prod-us-east-0.grafana.net`

**`grafana_stack_id`** (for the Nomad variable)
Your numeric stack ID, used as the basic auth username for the metrics API.
- Found on the same Connections → Data sources screen, in the "User" field.
- It's a number, e.g. `123456`.

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

### 5. Create the Nomad variable

Grafana Alloy needs credentials to federate metrics from Grafana Cloud.
Create the Nomad variable at path `nomad/jobs/grafana-alloy`:

```bash
nomad var put nomad/jobs/grafana-alloy \
  grafana_metrics_host="prometheus-prod-01-prod-us-east-0.grafana.net" \
  grafana_stack_id="123456" \
  grafana_api_key="glsa_xxxxxxxxxxxx"
```

The `grafana_api_key` here is the same service account token used in `terraform.tfvars`.

### 6. Deploy the updated Prometheus job

The Prometheus Nomad job now includes `--web.enable-remote-write-receiver`, which lets
Grafana Alloy push metrics into it. Redeploy if Prometheus is already running:

```bash
nomad job run nomad/monitoring/prometheus.hcl
```

### 7. Deploy the Grafana Alloy job

```bash
nomad job run nomad/infra/grafana-alloy/grafana-alloy.hcl
```

Check it's scraping successfully:
```bash
nomad alloc logs -f <alloc-id>
```

You should see log lines confirming the scrape and remote_write succeeded.

### 8. Verify in Prometheus

After one scrape interval (~60s), query in the Prometheus UI:
```
probe_success{source="grafana-sm"}
```

You should see one series per probe per check.

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
