# postgres

Runs a single PostgreSQL 16 instance pinned to `hedwig`, with a `pgbackup`
sidecar that writes daily encrypted dumps to a CSI volume.

## Jobs / tasks

| Task | Purpose |
|---|---|
| `postgres` | PostgreSQL 16.13 server, data on `/localssd/postgres` |
| `pgbackup` | Sidecar: dumps all non-system databases daily, encrypted |

## Prerequisites

### Nomad variables

Both tasks read from `nomad/jobs/postgres`. Create it with:

```
nomad var put nomad/jobs/postgres \
  pgpassword=<password> \
  pgbackup_key=<encryption-passphrase>
```

`pgbackup_key` is a passphrase used with `openssl enc -aes-256-cbc -pbkdf2`.
Choose something strong and store it somewhere safe — you need it to restore.

### CSI volume

Create the backup volume once before first deploy:

```
nomad volume create nomad/storage/volumes/pgbackup.hcl
```

## Backup details

`pgbackup.sh` runs a loop: on start it waits for postgres to accept
connections, dumps every database where `datistemplate = false`, then sleeps
24 hours and repeats. System databases (`template0`, `template1`) are
excluded; the `postgres` database is included.

Each database produces one file on the `pgbackup` CSI volume
(`rabbitseason:/mix`):

```
/backup/<dbname>.sql.enc
```

The file is the output of `pg_dump | openssl enc -aes-256-cbc -pbkdf2`,
overwritten on each run. Version history is kept by whatever backs up the
NFS volume externally.

The backup script lives at `nomad/infra/postgres/pgbackup.sh` in this repo
and is executed directly from the `gitrepo` CSI volume mount — no rebuild
needed when the script changes.

## Restoring a backup

### 1. Retrieve the encrypted dump from restic

```bash
# List snapshots to find the one you want
restic snapshots

# Restore a specific file from a snapshot
restic restore <snapshot-id> \
  --target /tmp/pgrestore \
  --include '<mount-path>/backup/<dbname>.sql.enc'
```

### 2. Get the encryption key

```bash
nomad var get -out table nomad/jobs/postgres
# note the value of pgbackup_key
```

### 3. Decrypt the dump

```bash
export PGBACKUP_KEY=<key-from-above>
openssl enc -d -aes-256-cbc -pbkdf2 \
  -pass env:PGBACKUP_KEY \
  -in /tmp/pgrestore/<dbname>.sql.enc \
  -out /tmp/<dbname>.sql
```

### 4. Restore to postgres

For a full replacement of an existing database:

```bash
# Drop and recreate (adjust connection flags as needed)
psql -h postgres.service.home.consul -U postgres \
  -c "DROP DATABASE IF EXISTS <dbname>;"
psql -h postgres.service.home.consul -U postgres \
  -c "CREATE DATABASE <dbname>;"
psql -h postgres.service.home.consul -U postgres \
  -d <dbname> < /tmp/<dbname>.sql
```

To restore into a new database without touching the original:

```bash
psql -h postgres.service.home.consul -U postgres \
  -c "CREATE DATABASE <dbname>_restored;"
psql -h postgres.service.home.consul -U postgres \
  -d <dbname>_restored < /tmp/<dbname>.sql
```
