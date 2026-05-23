# Proposal: OpenTelemetry-based observability stack (metrics + logs)

## Background

The cluster currently has a solid metrics pipeline: Prometheus scrapes all services, Grafana visualises them, and alerting is wired through Alertmanager. What is missing is centralised log collection. Container logs are only reachable today via `nomad alloc logs`, which requires knowing the allocation ID and is unavailable once an allocation is replaced.

This proposal adds a log collection and storage layer using OpenTelemetry Collector and VictoriaLogs, while keeping the existing Prometheus/Grafana metrics pipeline intact.

## Goals

- Centralised, queryable logs for all Nomad jobs.
- A single OTEL Collector endpoint per node that any app or sidecar can push metrics or logs to over OTLP.
- Logs stored in VictoriaLogs (on-prem, single binary, low resource cost).
- Logs queryable from Grafana alongside existing metrics dashboards.
- Minimal changes to existing jobs — most will get log collection for free via Docker log file tailing.

## Non-goals

- Replacing Prometheus scraping. Prometheus continues to own metrics collection and alerting as-is.
- Distributed tracing. Out of scope for this iteration.
- Sending anything off-cluster (no Grafana Cloud Loki, no external endpoints).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Each cluster node                                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  OTEL Collector  (Nomad system job, one per node)        │  │
│  │                                                          │  │
│  │  Receivers:                                              │  │
│  │   • filelog  — tails /var/lib/docker/containers/**/*.log │  │
│  │   • otlp     — listens on :4317 (gRPC) and :4318 (HTTP) │  │
│  │                                                          │  │
│  │  Exporters:                                              │  │
│  │   • otlphttp  → VictoriaLogs  (logs)                    │  │
│  │   • prometheus → Prometheus   (OTLP metrics from apps)  │  │
│  └──────────────────────────────────────────────────────────┘  │
│           ▲                  ▲                                  │
│    Docker log files    Apps pushing OTLP                        │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────┐     ┌──────────────────────────────────┐
│  VictoriaLogs        │     │  Prometheus (unchanged)           │
│  (Nomad service job) │     │  scrapes all existing targets     │
│  port 9428           │     │  port 9090                        │
└──────────┬───────────┘     └──────────────┬───────────────────┘
           │                                │
           └──────────────┬─────────────────┘
                          ▼
                  ┌───────────────┐
                  │   Grafana     │
                  │  (unchanged)  │
                  │  + VictoriaLogs datasource added
                  └───────────────┘
```

### Why VictoriaLogs

- Single binary, ~50–100 MB RAM at homelab scale — significantly lighter than a full Loki deployment.
- Native OTEL log ingestion via `/insert/opentelemetry/v1/logs`.
- LogsQL query language with a Grafana datasource plugin.
- arm64 builds available (covers picluster1–5).
- No object storage dependency: stores data on a local volume like a normal database.

### Why OTEL Collector as a system job

Running one Collector per node (Nomad `type = "system"`) means:

- The filelog receiver can read Docker log files from the local filesystem without any network hop.
- Each node's Collector has a fixed Consul address (`otel-collector.service.home.consul:4317`) that apps can push to.
- No single point of failure — losing one node doesn't affect log collection on others.

Docker log files live at `/var/lib/docker/containers/<id>/<id>-json.log` on each host. The Collector's filelog receiver tails these and parses the JSON Docker wraps around each line.

## New Nomad jobs

### `nomad/monitoring/victorialogs.hcl`

Single-task service job. Needs a CSI volume for persistent log storage (`monitoring` volume already exists and has free capacity, or a new `victorialogs` volume can be carved out). Pinned to a fixed host or allowed to float — floating is fine since it is stateful but the CSI volume follows it.

Key config:
- Port `9428` — VictoriaLogs HTTP API + query UI.
- Retention: set via `-retentionPeriod` flag (e.g. `30d`).
- Consul service registration so the Collector can resolve it.
- Traefik internal route for the VictoriaLogs UI (optional, useful for ad-hoc log browsing).

### `nomad/monitoring/otel-collector.hcl`

System job (one per node). Mounts the Docker socket directory read-only so the filelog receiver can tail container log files.

Key config:
- OTLP gRPC on `:4317`, OTLP HTTP on `:4318`.
- filelog receiver path: `/var/lib/docker/containers/*/*.log`.
- Exports logs to VictoriaLogs at `victorialogs.service.home.consul:9428`.
- Exports any received OTLP metrics to a Prometheus exposition endpoint (so Prometheus can scrape them if desired in future).

### `nomad/storage/volumes/victorialogs.hcl`

CSI volume on the `srv` NFS share (same as other stateful monitoring data).

## OTEL Collector config

The Collector config is templated into the job via a Nomad `template` block. Core structure:

```yaml
receivers:
  filelog:
    include:
      - /hostlog/containers/*/*.log
    include_file_path: true
    operators:
      # Docker wraps each line in JSON: {"log":"...", "stream":"stdout", "time":"..."}
      - type: json_parser
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%fZ'
      - type: move
        from: attributes.log
        to: body
      # Extract the container ID from the file path so logs can be correlated
      # with Nomad allocation IDs.
      - type: regex_parser
        regex: '/hostlog/containers/(?P<container_id>[a-f0-9]{12})'
        parse_from: attributes["log.file.path"]
        parse_to: attributes
      - type: move
        from: attributes.stream
        to: attributes["log.iostream"]

  otlp:
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"
      http:
        endpoint: "0.0.0.0:4318"

processors:
  batch:
    timeout: 5s

  # Attach the Nomad job name and task name as log resource attributes.
  # Docker labels set by Nomad (com.hashicorp.nomad.job_name etc.) are
  # available on the container and visible in the log JSON.
  resource:
    attributes:
      - action: insert
        key: host.name
        value: "${attr.unique.hostname}"  # injected by Nomad template

exporters:
  otlphttp/victorialogs:
    endpoint: "http://victorialogs.service.home.consul:9428/insert/opentelemetry"
    tls:
      insecure: true

  # Expose any OTLP metrics received from apps so Prometheus can scrape them.
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    logs:
      receivers: [filelog, otlp]
      processors: [batch]
      exporters: [otlphttp/victorialogs]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
```

The filelog path uses `/hostlog/containers` because the Nomad task mounts the host's `/var/lib/docker/containers` there (see job config below).

## Nomad job snippets

### otel-collector.hcl (outline)

```hcl
job "otel-collector" {
  datacenters = ["home"]
  type        = "system"

  group "otel-collector" {
    network {
      mode = "host"
      port "otlp_grpc" { static = 4317 }
      port "otlp_http" { static = 4318 }
      port "metrics"   { static = 8889 }
    }

    task "otel-collector" {
      driver = "docker"

      config {
        image   = "otel/opentelemetry-collector-contrib:0.123.0"
        args    = ["--config=/local/otel-collector.yml"]
        ports   = ["otlp_grpc", "otlp_http", "metrics"]
        volumes = [
          # Read-only mount so filelog can tail Docker container logs.
          "/var/lib/docker/containers:/hostlog/containers:ro",
        ]
      }

      template {
        destination = "local/otel-collector.yml"
        data        = <<EOH
# (full config as above, with {{ env "attr.unique.hostname" }} interpolated)
EOH
      }

      service {
        name = "otel-collector"
        port = "otlp_grpc"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```

`network { mode = "host" }` is used so the fixed ports (4317/4318) are stable on every node and routable without NAT.

### victorialogs.hcl (outline)

```hcl
job "victorialogs" {
  datacenters = ["home"]

  group "victorialogs" {

    volume "victorialogs" {
      type            = "csi"
      source          = "victorialogs"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    network {
      mode = "host"
      port "http" { static = 9428 }
    }

    task "victorialogs" {
      driver = "docker"

      config {
        image = "victoriametrics/victoria-logs:v1.23.0-victorialogs"
        args  = [
          "-storageDataPath=/data",
          "-retentionPeriod=30d",
          "-httpListenAddr=:9428",
        ]
        ports = ["http"]
      }

      volume_mount {
        volume      = "victorialogs"
        destination = "/data"
      }

      service {
        name = "victorialogs"
        port = "http"
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.victorialogs.rule=Host(`victorialogs.home.andvari.net`)",
          "traefik.http.routers.victorialogs.tls=true",
          "traefik.http.routers.victorialogs.tls.certresolver=le",
          "traefik.http.routers.victorialogs.middlewares=internal-only@file",
        ]
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }
}
```

## Existing jobs: what changes (and what doesn't)

### Most jobs — no changes required

Because the OTEL Collector's filelog receiver tails Docker log files at the host level, every container's stdout/stderr is automatically collected. No changes are needed to:

- `miniflux`, `birdnet`, `kutt`, `cringesweeper`, `mosquitto`, `nut2mqtt`, `postfix-andvari-smarthost` — all single-task jobs that already log to stdout.
- `prometheus`, `grafana`, `prom-alertmanager`, `prom-blackbox-exporter` — same.
- `traefik` — access logs and error logs go to stdout by default, will be collected automatically.

The Nomad job name, task name, and container ID are attached as attributes by parsing Docker's label metadata from the log file path.

### Multi-task jobs — no changes required either

`paperless` (webserver + redis + gotenberg + tika) and `immich` (server + machine-learning + redis + postgres) are multi-task groups. Each task runs as a separate Docker container, so each gets its own log file tailed individually. The container labels set by Nomad (`com.hashicorp.nomad.job_name`, `com.hashicorp.nomad.task_name`) are present in every Docker log file's metadata and attached as resource attributes.

### Jobs that could optionally push OTLP directly

Any app with native OTEL support can push structured logs (and metrics) over OTLP to `otel-collector.service.home.consul:4317` instead of relying on log file tailing. This gives richer structured data (fields rather than raw strings). Candidates:

**`nomad-botherer`** — written in Go; if it gets OTEL instrumentation, add:
```hcl
template {
  data = <<EOH
OTEL_EXPORTER_OTLP_ENDPOINT=http://{{ env "NOMAD_IP_otlp_grpc" }}:4317
OTEL_SERVICE_NAME=nomad-botherer
EOH
  destination = "secrets/otel.env"
  env         = true
}
```
Using `NOMAD_IP_*` here is intentional: in host-network mode the Collector's IP is the host IP, which is already bound. The Consul DNS address also works.

**`homelab-webhook`** — Python app; `opentelemetry-sdk` + `opentelemetry-exporter-otlp` can be added to the image.

For the rest (third-party images), file-based tailing is sufficient.

### `node_exporter` hosts (physical nodes, no Nomad)

The four Pi cluster nodes and the amd64 hosts run `node_exporter` for system metrics but have no Nomad allocation, so there are no Docker log files to tail there. System journal logs from these hosts are out of scope for this iteration. If needed in future, a lightweight agent (Vector or Promtail) installed via Ansible could ship journal logs to VictoriaLogs directly.

## Grafana changes

1. Install the **VictoriaLogs datasource plugin** (`victoriametrics-logs-datasource`) via `GF_INSTALL_PLUGINS` environment variable in the `grafana.hcl` job, or provision it via the gitrepo `monitoring/grafana/provisioning/` directory.
2. Add a provisioned datasource config at `monitoring/grafana/provisioning/datasources/victorialogs.yml`:

```yaml
apiVersion: 1
datasources:
  - name: VictoriaLogs
    type: victoriametrics-logs-datasource
    url: http://victorialogs.service.home.consul:9428
    access: proxy
    isDefault: false
```

3. No changes to existing Prometheus datasource or dashboards.

## Rollout order

1. Create `victorialogs` CSI volume (`nomad/storage/volumes/victorialogs.hcl`) and register it.
2. Deploy `victorialogs` job. Verify `/health` returns 200.
3. Deploy `otel-collector` system job. Verify it appears on all nodes via Consul.
4. Confirm logs are arriving: query VictoriaLogs at `:9428/select/logsql/query?query=*&limit=10`.
5. Add VictoriaLogs datasource to Grafana (plugin install + provisioning config, redeploy grafana job).
6. Add DNS entry `victorialogs.home.andvari.net` → Traefik (or rely on Consul only).

## Open questions / future work

- **Retention and storage sizing**: 30 days at homelab log volume should fit comfortably in a few GB. Monitor `victorialogs_data_size_bytes` (exposed at `:9428/metrics`) and adjust `-retentionPeriod` as needed.
- **Log-based alerting**: VictoriaLogs supports alerting via `vmalert` (VictoriaMetrics' alerting engine). A follow-on proposal could add log-pattern alerts (e.g. alert on error rate spikes in paperless or traefik).
- **System journal logs from bare-metal nodes**: Out of scope here; Ansible-deployed Vector would be the natural approach.
- **Traces**: If any app gains OTEL tracing, the Collector pipeline can be extended with a `traces` pipeline exporting to Tempo or a managed backend. No changes to the log/metrics pipelines required.
