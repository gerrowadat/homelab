# nomad/infra

Infrastructure services that apps depend on.

| Job | What it is | Notes |
|---|---|---|
| `postgres` | PostgreSQL database | Backed by CSI NFS volume |
| `mysql` | MySQL database | Backed by CSI NFS volume |
| `mosquitto` | MQTT broker | Used by Home Assistant, GivTCP, Z2M |
| `web` | nginx reverse proxy | Terminates SSL, routes to Consul service names |
| `certbot` | Let's Encrypt cert renewal | Pinned to `duckseason`; writes to local `/export/things/docker/ssl` |
| `letsencrypt-to-nomad-vars` | Copies renewed certs into Nomad variables | Pinned to `duckseason`; triggers nginx reload via variable update |
| `newt` | Pangolin tunnel client | Connects to external Pangolin server for remote access |
| `nut2mqtt` | UPS stats → MQTT | Reads from NUT daemons on UPS-attached hosts |
| `postfix-andvari-smarthost` | Internal Postfix smarthost | Relays outbound mail |
| `dns` | Consul-aware DNS | BIND9 forwarding `.consul` to local Consul agent |
| `z2m` | Zigbee2MQTT | See apps/ — listed here too as it's infrastructure for HASS |

## SSL certificate pipeline

Certificates are renewed by `certbot` and then propagated automatically:

```
certbot (runs on duckseason, writes to /export/things/docker/ssl)
  → letsencrypt-to-nomad-vars (reads certs, writes to Nomad vars)
    → web job template watches vars, sends SIGHUP to nginx on change
```

This means certificate renewals reach nginx without any manual steps or
container restarts.
