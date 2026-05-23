# Log collection

Centralised log storage and collection using OpenTelemetry Collector and
VictoriaLogs. All container stdout/stderr is tailed automatically from Docker
log files — no changes needed to existing jobs.

## Architecture

```
Each cluster node
┌─────────────────────────────────────────────────────────────────┐
│  otel-collector  (system job — one per node)                    │
│                                                                 │
│  filelog receiver  ← /var/lib/docker/containers/**/*.log        │
│  otlp receiver     ← apps pushing OTLP on :4317 (gRPC)         │
│                                        :4318 (HTTP)             │
│                                                                 │
│  → exports logs to VictoriaLogs via OTLP HTTP                   │
│  → exposes received OTLP metrics on :8889 (prometheus format)   │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────┐
│  victorialogs  (service job)         │
│  logs.service.home.consul:9428       │
│  30-day retention                    │
│  CSI volume: logs (mix NFS)          │
│  UI: https://logs.home.andvari.net   │
└──────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────┐
│  Grafana                             │
│  datasource: Logs (victoriametrics-  │
│  logs-datasource plugin)             │
└──────────────────────────────────────┘
```

### Log attributes collected

Each log record gets the following attributes from the filelog pipeline:

| Attribute | Source | Example |
|---|---|---|
| `host.name` | `NOMAD_NODE_NAME` (injected by OTEL Collector system job) | `picluster1` |
| `container_id` | Parsed from the Docker log file path | `a3f9d2c1b4e8` |
| `log.iostream` | Docker log JSON (`stream` field) | `stdout` / `stderr` |
| `log.file.path` | Full path of the tailed log file | `/hostlog/containers/...` |

Nomad job name and task name are not automatically attached — Docker label
metadata is not available without Docker socket access. Cross-reference
`container_id` with `docker ps` or `nomad alloc status` to trace a container
back to its allocation.

### Apps pushing OTLP directly

Any app with native OTEL support can push structured logs and metrics to
`otel-collector.service.home.consul:4317` (gRPC) or `:4318` (HTTP). Add to the
job's template block:

```hcl
template {
  data = <<EOH
OTEL_EXPORTER_OTLP_ENDPOINT=http://{{ env "NOMAD_IP_otlp_grpc" }}:4317
OTEL_SERVICE_NAME=my-service-name
EOH
  destination = "secrets/otel.env"
  env         = true
}
```

---

## Rollout

### Prerequisites

Verify the mix NFS CSI plugin is healthy on all nodes before creating the volume:

```bash
nomad plugin status rabbitseason-mix-nfs
```

All nodes should show `Healthy` in the `Node Plugins` table. If any are
unhealthy, check the `rabbitseason-mix-nfs-node` system job:

```bash
nomad job status rabbitseason-mix-nfs-node
```

### Step 1: Create the logs CSI volume

```bash
nomad volume create nomad/storage/volumes/logs.hcl
```

Verify it was created:

```bash
nomad volume status logs
```

### Step 2: Deploy VictoriaLogs

```bash
nomad job run nomad/monitoring/victorialogs/victorialogs.hcl
```

Wait for the allocation to become healthy, then check the health endpoint:

```bash
nomad job status victorialogs

# Health check — should return {"status":"ok"}
curl -s http://logs.service.home.consul:9428/health
```

If the allocation fails to place, check that the mix NFS volume is attachable:

```bash
nomad alloc status <alloc-id>   # look for volume mount errors in the events
```

### Step 3: Deploy the OTEL Collector system job

```bash
nomad job run nomad/monitoring/otel-collector/otel-collector.hcl
```

The system job schedules one allocation per cluster node. Verify placement:

```bash
nomad job status otel-collector
```

Every node in the cluster should appear in the allocation list with status
`running`. If a node is missing, check its allocation:

```bash
nomad alloc status <alloc-id>
nomad alloc logs <alloc-id> otel-collector   # look for config errors at startup
```

Common startup issues:
- **Config parse error**: the OTEL YAML in the template block is malformed. Check logs for `Error loading config`.
- **Port already in use**: another process holds 4317, 4318, or 8889. Rare on a clean node.
- **Cannot open log directory**: the `/var/lib/docker/containers` bind mount failed. Confirm Docker is running on the node.

### Step 4: Verify log ingestion

Wait 30–60 seconds for the filelog receiver to begin tailing, then query
VictoriaLogs directly:

```bash
# Fetch the 10 most recent log records (any source)
curl -s 'http://logs.service.home.consul:9428/select/logsql/query?query=*&limit=10' | jq .

# Filter to a specific node
curl -s 'http://logs.service.home.consul:9428/select/logsql/query' \
  --data-urlencode 'query=host.name:picluster1' \
  --data-urlencode 'limit=10' | jq .

# Filter to stderr only
curl -s 'http://logs.service.home.consul:9428/select/logsql/query' \
  --data-urlencode 'query=log.iostream:stderr' \
  --data-urlencode 'limit=10' | jq .
```

If no logs arrive after a couple of minutes, check OTEL Collector logs for
export errors:

```bash
# Pick any otel-collector allocation
nomad alloc logs <alloc-id> otel-collector 2>&1 | grep -i error
```

### Step 5: Redeploy Grafana

The `GF_INSTALL_PLUGINS=victoriametrics-logs-datasource` env var added to
`grafana.hcl` causes Grafana to download the plugin on startup. Redeploy to
pick up the change:

```bash
nomad job run nomad/monitoring/grafana.hcl
```

Plugin download requires internet access from the Grafana container. Watch the
logs to confirm it succeeds:

```bash
nomad alloc logs -f -job grafana grafana_server 2>&1 | grep -i plugin
# Expect: level=info msg="Plugin registered" pluginId=victoriametrics-logs-datasource
```

The `Logs` datasource is provisioned automatically from the gitrepo — no manual
Grafana UI steps needed. After Grafana is healthy, verify:

```bash
curl -s http://grafana.service.home.consul:3000/graphs/api/health

# List datasources (requires admin credentials)
curl -s -u admin:PASSWORD \
  http://grafana.service.home.consul:3000/api/datasources | jq '.[].name'
# Should include "Logs"
```

If the datasource is missing, trigger a provisioning reload:

```bash
curl -s -X POST -u admin:PASSWORD \
  http://grafana.service.home.consul:3000/api/admin/provisioning/datasources/reload
```

### Step 6: Reload BIND DNS

The `logs CNAME traefik.service.home.consul.` record was added to
`dns/etc-bind/db.home.andvari.net` with serial bumped to 56. Deploy the updated
zone file to ns1 (hedwig) and reload BIND.

Verify DNS resolves correctly once reloaded:

```bash
dig @192.168.100.250 logs.home.andvari.net
# Should return the Traefik IP (192.168.100.250) after CNAME resolution
```

### Step 7: Verify end-to-end

Open `https://logs.home.andvari.net` — the VictoriaLogs query UI should load.

In Grafana (`https://home.andvari.net/graphs/`):

1. Go to **Explore** and select the **Logs** datasource.
2. Run query `*` — recent logs from all containers should appear.
3. Confirm the Traefik HTTPS route is working (internal-only middleware applies).

---

## Operational playbook

### Check job status

```bash
nomad job status victorialogs
nomad job status otel-collector     # shows one alloc per node
```

### Tail live logs from the collector

```bash
# Pick a node's allocation ID from 'nomad job status otel-collector'
nomad alloc logs -f <alloc-id> otel-collector
```

### Query logs

VictoriaLogs uses [LogsQL](https://docs.victoriametrics.com/victorialogs/logsql/).
Key patterns:

```bash
BASE='http://logs.service.home.consul:9428/select/logsql/query'

# All logs, last 5 minutes (default time range is 1 hour)
curl -s "$BASE" --data-urlencode 'query=*' --data-urlencode '_time=5m' | jq .

# Logs from a specific container (get container_id from 'docker ps' or 'nomad alloc status')
curl -s "$BASE" --data-urlencode 'query=container_id:a3f9d2c1b4e8' | jq .

# Logs containing a string
curl -s "$BASE" --data-urlencode 'query=error' | jq .

# Stderr only from a specific host
curl -s "$BASE" \
  --data-urlencode 'query=host.name:hedwig AND log.iostream:stderr' | jq .
```

### Check storage usage

VictoriaLogs exposes Prometheus metrics at `:9428/metrics`. To check how much
disk the log store is using:

```bash
curl -s http://logs.service.home.consul:9428/metrics \
  | grep victorialogs_data_size_bytes
```

The `logs` CSI volume starts at 10 GB on the mix NFS share. If usage approaches
the limit, either reduce `-retentionPeriod` in `victorialogs.hcl` or resize the
volume on `rabbitseason`.

### Restart VictoriaLogs

```bash
nomad job run nomad/monitoring/victorialogs/victorialogs.hcl
```

VictoriaLogs stores data on the CSI volume — a restart does not lose data.

### Update OTEL Collector config

The collector config lives in the `template` block inside
`nomad/monitoring/otel-collector/otel-collector.hcl`. After editing:

```bash
nomad job run nomad/monitoring/otel-collector/otel-collector.hcl
```

Nomad will perform a rolling update across nodes (one at a time by default for
system jobs).

### Upgrade VictoriaLogs or the OTEL Collector

Update the image tag in the relevant `.hcl` file and redeploy:

```bash
# After editing the image tag:
nomad job run nomad/monitoring/victorialogs/victorialogs.hcl
nomad job run nomad/monitoring/otel-collector/otel-collector.hcl
```

---

## Future work

- **Job/task name enrichment**: Mount the Docker socket read-only into the
  OTEL Collector so the filelog receiver can read container labels
  (`com.hashicorp.nomad.job_name`, `com.hashicorp.nomad.task_name`) and attach
  them as log attributes. Not done initially to avoid the socket mount.
- **Log-based alerting**: Add `vmalert` (VictoriaMetrics alerting engine) to
  fire alerts on log patterns (e.g. error rate spikes, specific strings).
- **System journal logs**: Bare-metal nodes (picluster1–5, hedwig, etc.) have no
  Docker containers and no OTEL Collector. An Ansible-deployed Vector agent
  could ship journal logs to VictoriaLogs directly.
- **Traces**: If any app gains OTEL tracing, extend the OTEL Collector pipeline
  with a `traces` pipeline exporting to Tempo or a managed backend — no changes
  to the log pipeline needed.
