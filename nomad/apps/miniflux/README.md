# miniflux

[Miniflux](https://miniflux.app/) — minimal RSS/Atom feed reader.

Available at `https://home.andvari.net/rss` (path-based Traefik route).

## Dependencies

Requires a `miniflux` database in the postgres instance. Create it once:

```bash
bash scripts/pg-connect.sh
# Inside psql:
CREATE DATABASE miniflux;
CREATE USER miniflux WITH PASSWORD 'yourpassword';
GRANT ALL PRIVILEGES ON DATABASE miniflux TO miniflux;
```

`RUN_MIGRATIONS=1` is set so Miniflux manages its own schema on startup.

## Nomad variable

`nomad/jobs/miniflux` must contain:

| Key | Description |
|---|---|
| `postgres_pass` | Password for the `miniflux` postgres user |

```bash
nomad var put nomad/jobs/miniflux postgres_pass="..."
```

## Traefik routing

Uses a **path-based** route (`/rss`), defined in the `dynamic.yml` template
inside `nomad/infra/traefik/traefik.hcl`. The Nomad service block has no
Traefik tags.

## Deployment

```bash
nomad job run nomad/apps/miniflux/miniflux.hcl
```
