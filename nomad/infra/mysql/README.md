# mysql

MySQL 8.4 database server. Used by apps that require MySQL (e.g. Zigbee2MQTT).

Reachable at `mysql.service.home.consul:3306` from within the cluster.

## Storage

Uses the `mysql` CSI NFS volume mounted at `/var/lib/mysql`.

## Nomad variable

`nomad/jobs/mysql` must contain:

| Key | Description |
|---|---|
| `root_password` | MySQL root password |

```bash
nomad var put nomad/jobs/mysql root_password="..."
```

## Creating databases

Connect as root to create databases and users for apps:

```bash
nomad alloc exec -task mysql $(nomad job allocs mysql | awk 'NR==2{print $1}') \
  mysql -uroot -p"$ROOT_PASSWORD"
```

## Deployment

```bash
nomad job run nomad/infra/mysql/mysql.hcl
```
