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

## CSI volumes

Key volumes:
- `gitrepo` — git clone of this repo, served read-only to most jobs, read-write to `monitoring-webhook`. Mounted at `/config` by monitoring jobs; configs are under `/config/monitoring/`.
- `monitoring` — persistent data for prometheus TSDB and alertmanager state.
- `birdnet`, `jellyfin`, etc. — app-specific data volumes.

## Monitoring stack

Config files live in `monitoring/` and are mounted into prometheus/alertmanager/blackbox-exporter via the `gitrepo` CSI volume.

On push to main, the `monitoring-webhook` Nomad job (at `nomad/infra/monitoring-webhook/`) pulls the repo and POSTs `/-/reload` to prometheus (9090), alertmanager (9093), and blackbox-exporter (9115).

Prometheus requires `--web.enable-lifecycle` to enable `/-/reload`. Alertmanager and blackbox-exporter enable it by default.

Run `bash scripts/check-monitoring-configs.sh` to validate configs locally before pushing. CI runs the same checks on PRs/pushes touching `monitoring/`.

## CI

`.github/workflows/monitoring-validate.yml` runs on PRs and pushes to main that touch `monitoring/**`. Uses Docker to run `promtool`, `amtool`, and blackbox-exporter `--config.check`. Always use `--entrypoint promtool` when running `prom/prometheus` — its default entrypoint is `prometheus`, not `promtool`.
