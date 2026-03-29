# Claude Code hints for this repo

## Repo layout

```
ansible/          Host provisioning (Consul, Nomad, Docker, DNS, NFS, etc.)
dns/              BIND9 zone files for home.andvari.net (split-horizon)
docs/             Misc documentation
monitoring/       Prometheus config files (prometheus.yml, alert rules, etc.)
                  These are served to the cluster via the 'gitrepo' CSI volume.
nomad/
  acl/            Nomad ACL policies
  apps/           User-facing application jobs (birdnet, hass, miniflux, etc.)
  infra/          Infrastructure jobs (traefik, postgres, mysql, mosquitto, etc.)
  monitoring/     Monitoring stack jobs (prometheus, grafana, alertmanager, etc.)
  storage/        CSI plugin and volume definitions
scripts/          Utility scripts (validation, reload helpers)
.github/workflows/  CI (monitoring config validation)
```

## Working conventions

- **Always use a new branch** for every change, no matter how small. Never commit directly to main.
- **Always push the branch** to the remote before considering work done.
- **Keep documentation up to date**: if a job changes, update the relevant README in the same commit. Each `nomad/` subdirectory has a README listing what's in it.
- **Sync with remote** before starting work: `git checkout main && git pull` before branching.

## Nomad job conventions

- All jobs target `datacenters = ["home"]`.
- Job file lives at `nomad/<category>/<jobname>/<jobname>.hcl`.
- All tasks that expose a port should have a `service { name = "...", port = "..." }` stanza so they register with Consul.
- Secrets go in Nomad variables at `nomad/jobs/<jobname>`, injected via `template` blocks into `secrets/env` with `env = true`. Variables must be created manually before deploying.
- The `user` field (to run as a specific user) is a **task-level** field, not inside `config {}`.
- amd64-only images get a constraint: `attribute = "${attr.cpu.arch}" operator = "=" value = "amd64"`.

## Traefik routing

Two patterns — use the right one for each case:

**Hostname-based** (subdomain of home.andvari.net or standalone hostname): add tags to the Nomad `service` block:
```hcl
tags = [
  "traefik.enable=true",
  "traefik.http.routers.myjob.rule=Host(`thing.home.andvari.net`)",
  "traefik.http.routers.myjob.tls=true",
  "traefik.http.routers.myjob.tls.certresolver=le",
  "traefik.http.routers.myjob.middlewares=internal-only@file",  // omit for public routes
]
```

**Path-based** (under `home.andvari.net/path`): edit the `dynamic.yml` template in `nomad/infra/traefik/traefik.hcl` — add a router and service entry there. Do not use Nomad service tags for path-based routes.

`internal-only` middleware restricts to 192.168.100.0/24. Omit it for routes that must be publicly reachable (e.g. webhook receivers, ACME challenges).

Traefik is pinned to `hedwig` and owns ports 80/443. Certs are stored at `/localssd/traefik/acme.json`.

## Service DNS

All Nomad services with a `service` stanza register in Consul and are resolvable at:
```
<service-name>.service.home.consul:<port>
```

Use these addresses (not `*.home.nomad.andvari.net`) everywhere — in prometheus scrape targets, reload URLs, inter-service references, and Traefik backend definitions.

**Inter-task communication**: Docker tasks in the same Nomad group have separate network namespaces. Never use `127.0.0.1` to reach a sibling task — use its Consul DNS address instead.

## CSI volumes

Key volumes:
- `gitrepo` — git clone of this repo, served read-only to most jobs, read-write to `homelab-webhook`. Mounted at `/config` by monitoring jobs; configs are under `/config/monitoring/`.
- `monitoring` — persistent data for prometheus TSDB and alertmanager state.
- `birdnet`, `jellyfin`, etc. — app-specific data volumes.

## Monitoring stack

Config files live in `monitoring/` and are mounted into prometheus/alertmanager/blackbox-exporter via the `gitrepo` CSI volume.

On push to main, the `homelab-webhook` Nomad job (at `nomad/infra/homelab-webhook/`) pulls the repo and POSTs `/-/reload` to alertmanager (9093) and blackbox-exporter (9115).

Prometheus reloads automatically: its Nomad template uses `{{ file "/config/monitoring/prometheus.yml" }}`, so Nomad watches the gitrepo file for changes and sends SIGHUP to Prometheus when it changes. No explicit `/-/reload` call is needed for Prometheus config changes. Credential rotations (Nomad var changes) also trigger a graceful reload via the same mechanism.

Prometheus requires `--web.enable-lifecycle` to enable `/-/reload`. Alertmanager and blackbox-exporter enable it by default.

Run `bash scripts/check-monitoring-configs.sh` to validate configs locally before pushing. CI runs the same checks on PRs/pushes touching `monitoring/`.

## CI

`.github/workflows/monitoring-validate.yml` runs on PRs and pushes to main that touch `monitoring/**`. Uses Docker to run `promtool`, `amtool`, and blackbox-exporter `--config.check`. Always use `--entrypoint promtool` when running `prom/prometheus` — its default entrypoint is `prometheus`, not `promtool`.

## Quick operational reference

**Deploy / redeploy a job:**
```bash
nomad job run nomad/<category>/<jobname>/<jobname>.hcl
```

**Check job status and recent allocation:**
```bash
nomad job status <jobname>
nomad alloc status <allocid>
```

**View task logs:**
```bash
nomad alloc logs <allocid> [task-name]
nomad alloc logs -stderr <allocid> [task-name]
```

**Read/write a Nomad variable:**
```bash
nomad var get nomad/jobs/<jobname>
nomad var put nomad/jobs/<jobname> key=value key2=value2
```

**Open a postgres session:**
```bash
bash scripts/pg-connect.sh
```

**Validate monitoring configs before pushing:**
```bash
bash scripts/check-monitoring-configs.sh
```

**Reload Prometheus/Blackbox config (no restart needed):**
```bash
bash scripts/reload_prometheus.sh
bash scripts/reload_prometheus_blackbox.sh
```

## Key service URLs (internal network)

| Service | URL |
|---|---|
| Grafana | `http://grafana.service.home.consul:3000` or `https://home.andvari.net/graphs` |
| Prometheus | `http://prometheus.service.home.consul:9090` |
| Alertmanager | `http://prom-alertmanager.service.home.consul:9093` |
| Consul UI | `http://hedwig:8500` |
| Nomad UI | `http://hedwig:4646` |
| Traefik dashboard | `http://hedwig:8080` |

## Host inventory

| Host | Arch | Notable roles |
|---|---|---|
| `picluster1`–`picluster4` | arm64 | General cluster nodes |
| `picluster5` | arm64 | 3D printer (octoprint), Zigbee stick (z2m) |
| `hedwig` | amd64 | Traefik (ports 80/443), Home Assistant, on UPS |
| `rabbitseason` | amd64 | NFS server (CSI volumes) |
| `duckseason` | amd64 | On networking UPS; NUT daemon for UPS monitoring |

amd64-only images need: `constraint { attribute = "${attr.cpu.arch}" value = "amd64" }`

## Nomad variable paths (common jobs)

| Variable path | Used by |
|---|---|
| `nomad/jobs/prometheus` | `grafana_metrics_host`, `grafana_stack_id`, `grafana_metrics_read_token` |
| `nomad/jobs/grafana-cloud` | `grafana_cloud_url`, `grafana_api_key`, `sm_access_token`, `sm_url` |
| `nomad/jobs/traefik` | `gcp_credentials_json` (for DNS-01 ACME) |
| `nomad/jobs/grafana` | `grafana_admin_user`, `grafana_admin_password`, `grafana_db_password` |
| `nomad/jobs/postgres` | `postgres_password` |
| `nomad/jobs/mysql` | `root_password` |
