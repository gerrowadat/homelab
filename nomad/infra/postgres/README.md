# postgres

Runs a single PostgreSQL 16 instance pinned to `hedwig`.

Database backups are handled by [databasus](../databasus/README.md), which
stores dumps in its own CSI volume (`/databasus-data/backups`).

## Jobs / tasks

| Task | Purpose |
|---|---|
| `postgres` | PostgreSQL 16.13 server, data on `/localssd/postgres` |

## Prerequisites

### Nomad variables

Create the variable path before deploying:

```
nomad var put nomad/jobs/postgres pgpassword=<password>
```

## Restoring a backup

Backups are written by databasus to `rabbitseason:/srv/databasus/backups` and
picked up by restic from there.

### 1. Retrieve the dump from restic

```bash
restic snapshots
restic restore <snapshot-id> \
  --target /tmp/pgrestore \
  --include '<mount-path>/<dbname>.sql'
```

### 2. Restore to postgres

```bash
psql -h postgres.service.home.consul -U postgres \
  -c "DROP DATABASE IF EXISTS <dbname>;"
psql -h postgres.service.home.consul -U postgres \
  -c "CREATE DATABASE <dbname>;"
psql -h postgres.service.home.consul -U postgres \
  -d <dbname> < /tmp/pgrestore/<dbname>.sql
```
