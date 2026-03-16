# kutt

[kutt.it](https://github.com/thedevs-network/kutt) — self-hosted URL shortener.

Served at `https://go.home.andvari.net` (internal only).

## Dependencies

- **Postgres** — `postgres.service.home.consul:5432`, database and user both named `kutt`
- **SMTP** — `postfix-andvari-smarthost.service.home.consul:25`, no auth, from address `kutt@home.andvari.net`
- **CSI volume** — `kutt`, backed by `rabbitseason-srv-nfs`, mounted at `/data`
- **Traefik** — hostname routing, TLS via Let's Encrypt, `internal-only` middleware

## First-time setup

### 1. Create the postgres database and user

Connect to postgres and run:

```sql
CREATE USER kutt WITH PASSWORD 'choose-a-password';
CREATE DATABASE kutt OWNER kutt;
```

### 2. Create the Nomad variable

```sh
nomad var put nomad/jobs/kutt \
  postgres_pass='the-password-from-above' \
  jwt_secret='a-long-random-string'
```

Generate a suitable JWT secret with e.g. `openssl rand -hex 32`.

### 3. Register the CSI volume

```sh
nomad volume create nomad/storage/volumes/kutt.hcl
```

The volume is served from `rabbitseason:/srv` via the `rabbitseason-srv-nfs` CSI plugin.

### 4. Add DNS

Add an A record for `go.home.andvari.net` pointing at Traefik (hedwig) in `dns/`.

### 5. Deploy

```sh
nomad job run nomad/apps/kutt/kutt.hcl
```

Kutt runs database migrations automatically on first start.

## Ongoing operation

- Logs: `nomad alloc logs -job kutt`
- The first account registered becomes an admin. Register at `https://go.home.andvari.net` after deploying.
- To restrict registration after setup, set `DISALLOW_REGISTRATION=true` in the job template and redeploy.
