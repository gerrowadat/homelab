# Grafana

Grafana is deployed at `https://home.andvari.net/graphs/`. It uses PostgreSQL
for its database (no SQLite) and reads all provisioning config (datasources,
dashboard definitions) from the `gitrepo` CSI volume, so the full state of
dashboards is in version control.

## Architecture

```
GitHub push
  → homelab-webhook (port 9111)
      → git pull on gitrepo CSI volume
      → if monitoring/grafana/ changed:
          → POST /api/admin/provisioning/datasources/reload  (Grafana)
          → POST /api/admin/provisioning/dashboards/reload   (Grafana)

Grafana container
  → reads provisioning from /config/monitoring/grafana/provisioning/
     (gitrepo CSI volume, path monitoring/grafana/provisioning/)
  → polls /config/monitoring/grafana/dashboards/ every 30s for dashboard JSON
  → persists plugins and session state to grafana CSI volume (rabbitseason-srv-nfs)
  → stores all other state in PostgreSQL (postgres.service.home.consul:5432)

Traefik
  → routes home.andvari.net/graphs → grafana.service.home.consul:3000
  → internal-only middleware (192.168.100.0/24)
```

## First-time setup

### 1. Create the Postgres database

Connect as the postgres superuser and create the `grafana` role and database:

```bash
bash scripts/pg-connect.sh
```

```sql
CREATE USER grafana WITH PASSWORD 'choose-a-password';
CREATE DATABASE grafana OWNER grafana;
\q
```

### 2. Create the CSI volume

```bash
nomad volume create nomad/storage/volumes/grafana.hcl
```

### 3. Set Nomad variables for Grafana

```bash
nomad var put nomad/jobs/grafana \
  grafana_admin_user=admin \
  grafana_admin_password=<strong-password> \
  grafana_db_password=<postgres-grafana-password>
```

| Key                    | Description                                |
|------------------------|--------------------------------------------|
| `grafana_admin_user`   | Initial admin username                     |
| `grafana_admin_password` | Initial admin password                   |
| `grafana_db_password`  | Password for the `grafana` Postgres user   |

### 4. Update homelab-webhook variables

The webhook server needs the Grafana admin credentials to call the provisioning
reload API. Add them to the existing variable:

```bash
nomad var put nomad/jobs/homelab-webhook \
  github_webhook_secret=<existing-secret> \
  grafana_admin_user=admin \
  grafana_admin_password=<same-as-above> \
  nomad_token=<existing-token-if-any>
```

### 5. Deploy

```bash
nomad job run nomad/monitoring/grafana.hcl
nomad job run nomad/infra/traefik/traefik.hcl
nomad job run nomad/infra/homelab-webhook/homelab-webhook.hcl
```

### 6. Verify

```bash
# Check the job is running
nomad job status grafana

# Check Grafana is healthy
curl -s http://grafana.service.home.consul:3000/graphs/api/health

# Check Traefik can route to it
curl -sk https://home.andvari.net/graphs/api/health
```

---

## Adding dashboards

Dashboards are JSON files under `monitoring/grafana/dashboards/`. Grafana polls
this directory every 30 seconds (via `updateIntervalSeconds: 30` in the
dashboard provider). A webhook push to `main` also triggers an immediate reload.

### Workflow: design in the UI, save to git

1. Open `https://home.andvari.net/graphs/` and build the dashboard in the Grafana UI.
2. Once happy, export it: **Dashboard menu → Share → Export → Save to file**.
3. Save the JSON file to `monitoring/grafana/dashboards/<name>.json`.
4. Commit and push. The webhook will reload Grafana within seconds.

> Dashboard JSON exported from Grafana contains a `uid` field. Keep this stable
> across edits — Grafana uses it to match the file to the existing dashboard.
> If you delete the `uid`, Grafana will create a duplicate on next reload.

### Subdirectories as folders

If `foldersFromFilesStructure: true` is set (it is), subdirectories under
`monitoring/grafana/dashboards/` become Grafana folders:

```
monitoring/grafana/dashboards/
  nodes/
    cpu.json       → folder "nodes"
    memory.json    → folder "nodes"
  services/
    nomad.json     → folder "services"
```

### Removing a dashboard

Delete the JSON file and push. Grafana will remove the dashboard on the next
poll (since `disableDeletion: false`).

---

## Adding datasources

Datasource definitions live in
`monitoring/grafana/provisioning/datasources/*.yaml`. The Prometheus datasource
is pre-configured. To add another:

1. Create a new YAML file following the
   [Grafana datasource provisioning schema](https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources).
2. Commit and push. The webhook calls
   `POST /api/admin/provisioning/datasources/reload` automatically.

To reload manually without a push:

```bash
curl -s -X POST -u admin:PASSWORD \
  http://grafana.service.home.consul:3000/api/admin/provisioning/datasources/reload
```

---

## Playbook

### Check what Grafana is doing

```bash
# Job status
nomad job status grafana

# Live logs
nomad alloc logs -job grafana -f grafana_server

# Health endpoint
curl -s http://grafana.service.home.consul:3000/graphs/api/health

# List provisioned datasources
curl -s -u admin:PASSWORD \
  http://grafana.service.home.consul:3000/api/datasources | jq '.[].name'

# List provisioned dashboards
curl -s -u admin:PASSWORD \
  http://grafana.service.home.consul:3000/api/search | jq '.[].title'
```

### Manually trigger provisioning reload

```bash
GRAFANA=http://grafana.service.home.consul:3000
CREDS=admin:PASSWORD

curl -s -X POST -u "$CREDS" "$GRAFANA/api/admin/provisioning/datasources/reload"
curl -s -X POST -u "$CREDS" "$GRAFANA/api/admin/provisioning/dashboards/reload"
```

### Reset admin password

If the admin password is lost or needs rotating:

```bash
# Option 1: via Grafana CLI inside the container
nomad alloc exec -job grafana grafana_server \
  grafana-cli admin reset-admin-password NEW_PASSWORD

# Option 2: update the Nomad variable and redeploy
nomad var put nomad/jobs/grafana \
  grafana_admin_user=admin \
  grafana_admin_password=NEW_PASSWORD \
  grafana_db_password=<existing-db-password>
nomad job run nomad/monitoring/grafana.hcl
```

After rotating the password, also update `nomad/jobs/homelab-webhook`:

```bash
nomad var put nomad/jobs/homelab-webhook \
  github_webhook_secret=<existing> \
  grafana_admin_user=admin \
  grafana_admin_password=NEW_PASSWORD \
  nomad_token=<existing-if-any>
# Redeploy webhook to pick up the new env var
nomad job run nomad/infra/homelab-webhook/homelab-webhook.hcl
```

### Upgrade Grafana

1. Update the image tag in `nomad/monitoring/grafana.hcl`.
2. Commit, push, and redeploy:

```bash
nomad job run nomad/monitoring/grafana.hcl
```

Grafana will run any database migrations automatically on startup. The
PostgreSQL backend ensures no data is lost during upgrades.

### Inspect the database

```bash
bash scripts/pg-connect.sh
\c grafana
\dt                      -- list tables
SELECT title FROM dashboard;
SELECT name FROM data_source;
```

### Restore from backup

Grafana's state is in the `grafana` Postgres database, backed up daily by the
`pgbackup` sidecar. Follow the restore procedure in
`nomad/infra/postgres/README.md`, restoring the `grafana` database.

After restoring, restart the Grafana job to clear any in-memory cache:

```bash
nomad job run nomad/monitoring/grafana.hcl
```

---

## Next steps

- **Add dashboards**: Start with node_exporter metrics — the recording rules in
  `monitoring/node_exporter_recording_rules.yml` pre-compute CPU, memory, disk
  I/O, and network metrics ready for use. Export from the UI and commit.

- **Alerting**: Grafana can also send alerts. For now, alerting is handled by
  Alertmanager — evaluate whether to consolidate or keep them separate.

- **Grafana plugins**: Add plugin IDs to `GF_INSTALL_PLUGINS` in `grafana.hcl`
  (e.g. `GF_INSTALL_PLUGINS=grafana-piechart-panel`). They download at startup
  and persist to the `grafana` CSI volume.

- **Additional datasources**: Loki for log aggregation, if added later, just
  needs a file in `monitoring/grafana/provisioning/datasources/`.

- **Organisation/teams**: Grafana supports multiple orgs and teams. For a
  single-user homelab the default org is fine.
