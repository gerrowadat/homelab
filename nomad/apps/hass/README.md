# hass

Home Assistant — home automation hub.

- URL: hostname set via `hass_hostname` in `nomad/jobs/traefik` (internal network only)
- Port: 8123 (host network)
- Config volume: `hass` CSI NFS volume, mounted at `/config`
- Database: shared Postgres (`homeassistant` DB), used by the recorder integration

## Prerequisites

### 1. Create the Postgres database and user

```bash
bash scripts/pg-connect.sh
```

```sql
CREATE DATABASE homeassistant;
CREATE USER homeassistant WITH PASSWORD 'yourpassword';
GRANT ALL PRIVILEGES ON DATABASE homeassistant TO homeassistant;
-- Must connect to the target DB before granting on its public schema (PG15+)
\c homeassistant
GRANT ALL ON SCHEMA public TO homeassistant;
\q
```

### 2. Register the CSI volume

```bash
nomad volume create nomad/storage/volumes/hass.hcl
```

### 3. Create the Nomad variable for HA secrets

```bash
nomad var put nomad/jobs/hass db_password=yourpassword hostname=hass.example.com
```

`hostname` is used by HA for `external_url`/`internal_url` in `configuration.yaml`. It should match the value you set for `hass_hostname` in `nomad/jobs/traefik` (step 4).

### 4. Add the hostname to the Traefik variable

Open the Nomad UI → Variables → `nomad/jobs/traefik` and add key `hass_hostname` with the same hostname. Then redeploy Traefik to pick up the new routing rule.

## Deploy

```bash
nomad job run nomad/apps/hass/hass.hcl
```

On first deploy, the `hass-init` prestart task writes a starter `configuration.yaml`
to the volume. Subsequent deploys are a no-op for that file — edit it directly on the
NFS volume to customise HA.

## Notes

- **Image version**: Check `ghcr.io/home-assistant/home-assistant` tags and pin to the
  latest stable (format `YYYY.M.X`) before deploying.
- **HACS**: Install via the UI after onboarding. The NFS volume has plenty of space for
  custom components.
- **SQLite**: Not used — the recorder is configured to write history to Postgres from
  first boot, so `home-assistant_v2.db` will not be created on the NFS volume.
- **Zigbee**: Z2M runs on `picluster5` and publishes to `mosquitto`. Add the MQTT
  integration in the HA UI pointing at `mosquitto.service.home.consul`.
