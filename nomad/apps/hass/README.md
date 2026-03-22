# hass

[Home Assistant](https://www.home-assistant.io/) — home automation hub.

Pinned to `hedwig` because configuration and the SQLite database live on
the local SSD (`/localssd/hass`). NFS-backed storage causes database
corruption with Home Assistant.

> **Note:** The job is currently disabled (`count = 0`). Set `count = 1`
> to enable it.

## Storage

Bind-mounted from `/localssd/hass` on `hedwig`. This is intentionally
not a CSI volume — Home Assistant's SQLite database does not tolerate NFS.

Python user packages (HACS integrations, etc.) are installed into
`/localssd/hass/deps` and persist across container restarts via
`PYTHONUSERBASE`.

## Networking

Exposed internally at `hass.service.home.consul:8123`. No Traefik route
is defined — access is direct via Consul DNS.

## Deployment

```bash
# Enable (set count = 1 in hass.hcl first)
nomad job run nomad/apps/hass/hass.hcl
```
