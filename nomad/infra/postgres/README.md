# postgres

Runs a single PostgreSQL 16 instance pinned to `hedwig`.

Database backups are handled by [databasus](../databasus/README.md), which
mounts the `pgbackup` CSI volume and runs scheduled dumps via its web UI.

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

### CSI volume

The `pgbackup` volume is owned by the `databasus` job. Create it once before
deploying databasus:

```
nomad volume create nomad/storage/volumes/pgbackup.hcl
```

## Restoring a backup

Backups are SQL dumps written to the `pgbackup` CSI volume (`rabbitseason:/mix`)
by databasus. Restic backs up that NFS path externally.

### 1. Retrieve the dump from restic

```bash
restic snapshots
restic restore <snapshot-id> \
  --target /tmp/pgrestore \
  --include '<mount-path>/pgbackup/<dbname>.sql'
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
