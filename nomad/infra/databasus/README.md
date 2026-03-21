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

### CSI volumes

Create all three volumes before first deploy:

```bash
nomad volume create nomad/storage/volumes/databasus.hcl
nomad volume create nomad/storage/volumes/pgbackup.hcl     # already exists
nomad volume create nomad/storage/volumes/mysqlbackup.hcl
```

## Initial setup

After deploying, open `https://databasus.home.andvari.net` and configure:

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
