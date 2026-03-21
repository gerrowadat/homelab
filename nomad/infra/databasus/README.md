# databasus

[Databasus](https://databasus.com) is a self-hosted database backup tool with a web UI, rotation policies, and support for multiple storage destinations. It replaces the hand-rolled `pgbackup.sh` sidecar.

Accessible at `https://home.andvari.net/databasus` (internal-only).

## Jobs / tasks

| Task | Purpose |
|---|---|
| `databasus` | Web UI + backup scheduler for PostgreSQL and MySQL |

## Volumes

| Volume | CSI plugin | Mount | Purpose |
|---|---|---|---|
| `databasus` | `rabbitseason-srv-nfs` | `/databasus-data` | Databasus app state (config, schedules, audit log) |
| `pgbackup` | `rabbitseason-mix-nfs` | `/pgbackup` | Postgres backup destination (backed up by restic) |
| `mysqlbackup` | `rabbitseason-mix-nfs` | `/mysqlbackup` | MySQL backup destination (backed up by restic) |

## Prerequisites

### Nomad variables

The databasus job reads database credentials from its own variable path
(`nomad/jobs/databasus`). Copy the passwords from the existing postgres and
mysql variables:

```bash
nomad var put nomad/jobs/databasus \
  postgres_password=$(nomad var get -out json nomad/jobs/postgres | jq -r '.Items.pgpassword') \
  mysql_root_password=$(nomad var get -out json nomad/jobs/mysql | jq -r '.Items.root_password')
```

### NFS directory ownership (one-time, on rabbitseason)

The databasus container's entrypoint runs `chown -R postgres:postgres /databasus-data`
where postgres is uid=100, gid=102. With root_squash on the NFS export the
container can't chown the directory unless it's already owned correctly. Run
once on rabbitseason before first deploy:

```bash
sudo mkdir -p /srv/databasus
sudo chown -R 100:102 /srv/databasus
```

### CSI volumes

Create all three volumes before first deploy:

```bash
nomad volume create nomad/storage/volumes/databasus.hcl
nomad volume create nomad/storage/volumes/pgbackup.hcl     # already exists
nomad volume create nomad/storage/volumes/mysqlbackup.hcl
```

## Initial setup

After deploying, open `https://home.andvari.net/databasus` and configure:

**PostgreSQL:**
- Host: `postgres.service.home.consul`, port `5432`
- User: `postgres`
- Password: from `POSTGRES_ADMIN_PASSWORD` env var (injected at runtime)
- Backup destination: local path `/pgbackup`

**MySQL:**
- Host: `mysql.service.home.consul`, port `3306`
- User: `root`
- Password: from `MYSQL_ROOT_PASSWORD` env var (injected at runtime)
- Backup destination: local path `/mysqlbackup`

Set up a rotation schedule (daily/weekly/monthly) to keep backup storage bounded.
