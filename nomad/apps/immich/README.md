# immich

[Immich](https://immich.app) — self-hosted photo and video management.

The public hostname is stored in the `nomad/jobs/traefik` variable (not in
this repo) and is not added to local DNS — it resolves via public DNS to
Traefik on hedwig.

## Architecture

All four services run as tasks in a single Nomad job group:

| Task | Image | Port |
|---|---|---|
| `immich-server` | `ghcr.io/immich-app/immich-server:release` | 2283 |
| `immich-ml` | `ghcr.io/immich-app/immich-machine-learning:release` | 3003 |
| `immich-redis` | `redis:7-alpine` | 6379 |
| `immich-db` | `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0` | 5433 |

Immich requires its own postgres (with the vectorchord extension) — it does
not use the shared `postgres` job. Port 5433 is used to avoid collision with
the shared postgres on 5432.

Machine learning runs CPU-only (hedwig has an Intel Iris 6100 iGPU; OpenVINO
support for Broadwell Gen 8 is limited).

## Storage

| Volume | NFS share | Contents |
|---|---|---|
| `immich-photos` | `rabbitseason:/mix` | Photo and video library |
| `immich-db` | `rabbitseason:/srv` | Postgres data directory |

## First-time setup

### 1. Create the immich Nomad variable

```bash
nomad var put nomad/jobs/immich \
  db_password='choose-a-strong-password'
```

### 2. Add the hostname to the Traefik variable

The Traefik dynamic config reads `immich_hostname` from `nomad/jobs/traefik`.
Add it while preserving all existing keys:

```bash
nomad var get -out json nomad/jobs/traefik \
  | jq '.Items.immich_hostname = "<your-hostname>"' \
  | nomad var put -in json nomad/jobs/traefik -
```

Once set, Nomad re-renders Traefik's dynamic config and the route becomes
active automatically — no Traefik redeploy needed.

### 3. Create the CSI volumes

```bash
nomad volume create nomad/storage/volumes/immich-photos.hcl
nomad volume create nomad/storage/volumes/immich-db.hcl
```

### 4. Deploy

```bash
nomad job run nomad/apps/immich/immich.hcl
```

Immich runs database migrations automatically on first start. The initial
startup takes longer than usual while migrations run and the machine learning
container downloads its models (~few hundred MB).

## Ongoing operation

```bash
# Logs
nomad alloc logs -job immich immich-server
nomad alloc logs -job immich immich-ml
nomad alloc logs -job immich immich-db

# Status
nomad job status immich
```

The first account registered becomes the admin. After initial setup, external
registration can be disabled in the Immich admin panel.
