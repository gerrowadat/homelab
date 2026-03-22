# homelab

Live config for my homelab — a Nomad/Consul cluster running at home.

Secrets and account-specific values are kept out of git via Nomad variables
and gitignored local files. Some things reference external resources that only
exist on my LAN, but the structure should be readable and reusable.

## Hardware

| Host | Type | Role |
|---|---|---|
| `picluster1`–`picluster4` | Raspberry Pi 4 8GB | Nomad/Consul cluster nodes |
| `picluster5` | Raspberry Pi 4 8GB | Nomad/Consul node; has 3D printer and Zigbee USB stick attached |
| `hedwig` | Intel NUC | Nomad/Consul node; runs Traefik (ports 80/443); on UPS |
| `rabbitseason` | NUC-class | Nomad/Consul node; NFS server for CSI volumes; doubles as desktop |
| `duckseason` | Odroid | Nomad/Consul node; on UPS with networking kit |

All nodes run Ubuntu LTS, provisioned via `ansible/`.

## Architecture

```
Consul + Nomad cluster (all hosts)
  ├── Traefik (hedwig) — reverse proxy, TLS via Let's Encrypt
  ├── NFS CSI volumes (served from rabbitseason)
  ├── Monitoring stack — Prometheus, Alertmanager, Grafana, Blackbox Exporter
  ├── Infrastructure services — postgres, mysql, mosquitto, postfix, …
  └── Applications — Home Assistant, Miniflux, BirdNET, Octoprint, …
```

DNS is split-horizon BIND9 (`dns/`): `home.andvari.net` resolves locally to
internal IPs. All services register in Consul and are reachable at
`<service>.service.home.consul` from within the cluster.

## Repo layout

```
ansible/          Host provisioning (Consul, Nomad, Docker, DNS, NFS, etc.)
dns/              BIND9 zone files for home.andvari.net (split-horizon)
docs/             Setup guides and operational documentation
monitoring/       Prometheus, Alertmanager, and Blackbox Exporter config
nomad/
  acl/            Nomad ACL policies
  apps/           User-facing application jobs
  infra/          Infrastructure service jobs
  monitoring/     Monitoring stack jobs
  storage/        CSI plugin and volume definitions
scripts/          Utility scripts (validation, reload helpers, export tools)
terraform/        Terraform configs for external services
  grafana-sm/     Grafana Cloud Synthetic Monitoring checks
.github/workflows/  CI (monitoring config validation)
```

## Development

See [CLAUDE.md](CLAUDE.md) for working conventions, Nomad job patterns,
Traefik routing, and other repo-specific guidance.
