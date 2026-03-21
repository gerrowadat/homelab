# nomad/infra

Infrastructure services that apps depend on.

| Job | What it is | Notes |
|---|---|---|
| `traefik` | Reverse proxy, SSL termination, ACME cert management | |
| `postgres` | PostgreSQL database | Backed by CSI NFS volume |
| `mysql` | MySQL database | Backed by CSI NFS volume |
| `databasus` | Database backup UI | Backs up postgres → `pgbackup` volume, mysql → `mysqlbackup` volume |
| `mosquitto` | MQTT broker | Used by Home Assistant, GivTCP, Z2M |
| `newt` | Pangolin tunnel client | Connects to external Pangolin server for remote access |
| `nut2mqtt` | UPS stats → MQTT | Reads from NUT daemons on UPS-attached hosts |
| `postfix-andvari-smarthost` | Internal Postfix smarthost | Relays outbound mail |
| `dns` | Consul-aware DNS | BIND9 forwarding `.consul` to local Consul agent |
| `homelab-webhook` | GitHub webhook receiver | Pulls gitrepo and reloads monitoring services on push to main |

## SSL certificate pipeline

Traefik handles the full certificate lifecycle automatically:

```
Traefik (runs on hedwig, port 80/443)
  → DNS-01 ACME challenge via GCP Cloud DNS (gcp_credentials_json in nomad/jobs/traefik Nomad variable)
    → Certificates stored in /localssd/traefik/acme.json on hedwig
      → Served directly by Traefik; renewed automatically before expiry
```

Services opt into TLS by adding tags to their Nomad `service` block.
See `traefik/README.md` for full details.
