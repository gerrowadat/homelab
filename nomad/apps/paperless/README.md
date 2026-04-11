# paperless

[Paperless-ngx](https://docs.paperless-ngx.com/) — self-hosted document management with OCR.

Served at the hostname stored in `nomad/jobs/traefik` → `paperless_hostname` (publicly accessible, no `internal-only` middleware).

## Architecture

All four services run as tasks in a single Nomad job group:

| Task | Image | Port | Role |
|---|---|---|---|
| `paperless-webserver` | `paperlessngx/paperless-ngx:2.20.13` | 8000 | Web UI, API, background consumer |
| `paperless-redis` | `redis:7-alpine` | 6380 | Task queue and job broker |
| `paperless-gotenberg` | `gotenberg/gotenberg:8.10.1` | 3001 | Office doc → PDF conversion |
| `paperless-tika` | `apache/tika:3.0.0.0` | 9998 | Content extraction from Office/email |

Redis, Gotenberg, and Tika are prestart sidecars — they start before the webserver and keep running alongside it.

Uses the shared `postgres` job (no special extensions required).

## Storage

| Volume | NFS share | Mount | Contents |
|---|---|---|---|
| `paperless-data` | `rabbitseason:/srv` | `/data` | Search index, application state |
| `paperless-media` | `rabbitseason:/mix` | `/media` | Stored documents and thumbnails |
| `paperless-consume` | `rabbitseason:/mix` | `/consume` | Input directory (drop files here) |
| `paperless-export` | `rabbitseason:/mix` | `/export` | Backup exports |

The consume directory is on NFS, so `inotify` is not used — paperless polls every 60 seconds (`PAPERLESS_CONSUMER_POLLING=60`). Documents dropped into the consume volume are picked up within a minute.

## First-time setup

### 1. Create the postgres database and user

```bash
bash scripts/pg-connect.sh
```

```sql
CREATE USER paperless WITH PASSWORD 'choose-a-strong-password';
CREATE DATABASE paperless OWNER paperless;
```

### 2. Create the Nomad variable for paperless

Generate a secret key:

```bash
openssl rand -base64 48
```

```bash
nomad var put nomad/jobs/paperless \
  db_password='the-password-from-above' \
  secret_key='the-generated-key' \
  admin_user='admin' \
  admin_password='choose-a-strong-password'
```

### 3. Add the hostname to the Traefik variable

This controls both the Traefik routing rule and the `PAPERLESS_URL` / CSRF settings injected into the container:

```bash
nomad var get -out json nomad/jobs/traefik \
  | jq '.Items.paperless_hostname = "<your-hostname>"' \
  | nomad var put -in json nomad/jobs/traefik -
```

### 4. Add a public DNS A record

Point `<your-hostname>` at Traefik (hedwig, port 443) in your external DNS provider. No entry is needed in the internal BIND9 zone — internal clients resolve via public DNS, which also reaches Traefik directly.

### 5. Create the CSI volumes

```bash
nomad volume create nomad/storage/volumes/paperless-data.hcl
nomad volume create nomad/storage/volumes/paperless-media.hcl
nomad volume create nomad/storage/volumes/paperless-consume.hcl
nomad volume create nomad/storage/volumes/paperless-export.hcl
```

### 6. Redeploy Traefik

The Traefik dynamic config is re-rendered by Nomad when the variable changes, but redeploying ensures the new route is active immediately:

```bash
nomad job run nomad/infra/traefik/traefik.hcl
```

### 7. Deploy paperless

```bash
nomad job run nomad/apps/paperless/paperless.hcl
```

Paperless runs database migrations automatically on first start. First startup is slower than usual.

### 8. Log in

Navigate to `https://<your-hostname>` and log in with the `admin_user` and `admin_password` you set in step 2. The admin account is created automatically from the Nomad variable — no further setup is needed in the UI.

## NFS permissions

Paperless runs as the internal `paperless` user (UID 1000 by default). If the NFS volumes are owned by a different UID, the consumer will fail to delete files after processing them. Fix by setting `USERMAP_UID` and `USERMAP_GID` in the job's env template to match the owning UID/GID on the NFS server.

## Ongoing operation

```bash
# Logs
nomad alloc logs -job paperless paperless-webserver
nomad alloc logs -job paperless paperless-redis
nomad alloc logs -job paperless paperless-gotenberg
nomad alloc logs -job paperless paperless-tika

# Status
nomad job status paperless
```

### Exporting documents (backup)

```bash
nomad alloc exec -job paperless -task paperless-webserver \
  document_exporter /export
```

Files are written to the `paperless-export` CSI volume on mix.

### Consuming documents manually

Drop files into the `paperless-consume` CSI volume (mounted at `/consume` inside the container). They will be picked up within 60 seconds. Supported formats: PDF, PNG, JPG, TIFF, and (with Tika+Gotenberg) DOCX, XLSX, PPTX, EML, and more.
