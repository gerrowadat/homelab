# Secret Rotation Runbook

## How Nomad variable rotation works

Secrets live in Nomad variables at `nomad/jobs/<jobname>`. Jobs read them via
`template` blocks. When a variable changes, Nomad detects it and applies the
template's `change_mode` — the default is `restart`, so the affected task
restarts automatically within a few seconds. Only `prometheus` has an explicit
`change_mode = "restart"` annotation; all others rely on this default.

**Use `scripts/nomad-var-set.sh` to update a single key** without touching the
other keys in the same variable:

```bash
bash scripts/nomad-var-set.sh nomad/jobs/<jobname> <key> <new-value>
```

This pipes the current variable through `jq` to update just the one key, then
writes it back. Using `nomad var put` directly replaces all keys, so any key
you omit is silently deleted.

**Database password rotations require the password to be changed in the
database first.** The `POSTGRES_PASSWORD` / `MYSQL_ROOT_PASSWORD` env vars
only apply on first container initialisation; they do not change an existing
database's credentials. Change the password in the DB, then update the Nomad
variable.

---

## PostgreSQL root password (`nomad/jobs/postgres`)

**Keys:** `pgpassword`

**Generate:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW
```

**Change the password in the running database first:**
```bash
bash scripts/pg-connect.sh
ALTER USER postgres WITH PASSWORD 'NEW_PW_HERE';
\q
```

**Update the variable:**
```bash
bash scripts/nomad-var-set.sh nomad/jobs/postgres pgpassword NEW_PW_HERE
```

Postgres restarts automatically. The data directory already has the new
password; the restart is harmless.

**Verify:**
```bash
nomad job status postgres
bash scripts/pg-connect.sh
```

---

## MySQL root password (`nomad/jobs/mysql`)

**Keys:** `root_password`

**Generate:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW
```

**Change the password in the running database first:**
```bash
bash scripts/mysql-connect.sh
ALTER USER 'root'@'%' IDENTIFIED BY 'NEW_PW_HERE';
FLUSH PRIVILEGES;
exit
```

**Update the variable:**
```bash
bash scripts/nomad-var-set.sh nomad/jobs/mysql root_password NEW_PW_HERE
```

MySQL restarts automatically.

**Verify:**
```bash
nomad job status mysql
bash scripts/mysql-connect.sh
```

---

## Grafana admin credentials and database password (`nomad/jobs/grafana`)

**Keys:** `grafana_admin_user`, `grafana_admin_password`, `grafana_db_password`

### grafana_admin_password

Grafana stores its own admin password in its database, independently of the
env var. Change the password in Grafana first, then update the variable so they
stay in sync.

```bash
# Change via Grafana API (or through the web UI under Profile → Change Password)
curl -X PUT \
  -H "Content-Type: application/json" \
  -u admin:CURRENT_PASSWORD \
  -d '{"oldPassword":"CURRENT_PASSWORD","newPassword":"NEW_PW","confirmNew":"NEW_PW"}' \
  http://grafana.service.home.consul:3000/api/user/password
```

**Generate:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW
```

**Update the variable:**
```bash
bash scripts/nomad-var-set.sh nomad/jobs/grafana grafana_admin_password NEW_PW_HERE
```

### grafana_db_password

**Generate and change in PostgreSQL first:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW

bash scripts/pg-connect.sh
ALTER USER grafana WITH PASSWORD 'NEW_PW_HERE';
\q
```

**Update the variable:**
```bash
bash scripts/nomad-var-set.sh nomad/jobs/grafana grafana_db_password NEW_PW_HERE
```

Grafana restarts automatically and reconnects with the new password.

---

## Prometheus / Grafana Cloud credentials (`nomad/jobs/prometheus`)

**Keys:** `grafana_metrics_host`, `grafana_stack_id`, `grafana_metrics_read_token`

`grafana_metrics_host` and `grafana_stack_id` (the stack's numeric ID) do not
change. Only `grafana_metrics_read_token` needs rotation.

**Generate a new token:**
In the Grafana Cloud portal: *My Account → Stack → Access Policies → Create
token* (scope: `metrics:read`). Note the token value — it is shown only once.

**Update the variable:**
```bash
bash scripts/nomad-var-set.sh nomad/jobs/prometheus grafana_metrics_read_token NEW_TOKEN_HERE
```

Prometheus has `change_mode = "restart"` on this template. It restarts
automatically, reconnects to Grafana Cloud, and resumes remote_read.

**Verify:**
```bash
nomad job status prometheus
curl -s http://prometheus.service.home.consul:9090/-/healthy
```

---

## Traefik — GCP DNS credentials and Nomad token (`nomad/jobs/traefik`)

**Keys:** `gcp_credentials_json`, `gce_project`, `acme_email`, `nomad_token`,
and optional routing helpers (`home_ip`, `birdnet_hostname`, `kutt_hostname`,
`immich_hostname`).

### gcp_credentials_json (ACME DNS-01 challenge)

Rotate in the GCP console:
1. *IAM & Admin → Service Accounts → [traefik-acme account] → Keys → Add Key*
2. Download the new JSON key.
3. Delete the old key.

**Update the variable** (collapse the JSON to a single line first):
```bash
NEW_CREDS=$(cat new-key.json | jq -c .)
bash scripts/nomad-var-set.sh nomad/jobs/traefik gcp_credentials_json "$NEW_CREDS"
```

Traefik restarts. Existing ACME certificates in `/localssd/traefik/acme.json`
are not affected; the new credentials are only used at next renewal.

### nomad_token (Traefik Nomad provider)

**Create a new token** with the traefik-policy:
```bash
NEW_TOKEN=$(nomad acl token create -name=traefik-provider \
  -policy=traefik-policy \
  | grep 'Secret ID' | awk '{print $4}')
echo $NEW_TOKEN
```

**Update the variable:**
```bash
bash scripts/nomad-var-set.sh nomad/jobs/traefik nomad_token "$NEW_TOKEN"
```

**Revoke the old token** once Traefik has restarted and is healthy:
```bash
nomad acl token list   # find the old accessor ID
nomad acl token delete <old_accessor_id>
```

---

## homelab-webhook (`nomad/jobs/homelab-webhook`)

**Keys:** `github_webhook_secret`, `grafana_admin_user`, `grafana_admin_password`,
`nomad_token`

### github_webhook_secret

**Generate:**
```bash
NEW_SECRET=$(openssl rand -hex 32)
echo $NEW_SECRET
```

**Update in GitHub** before updating the Nomad variable — GitHub starts signing
deliveries with the new secret immediately:
*GitHub repo → Settings → Webhooks → [webhook URL] → Edit → Secret → paste →
Update webhook.*

Do this for both webhook URLs:
- `https://home.andvari.net/webhooks/monitoring-reload`
- `https://home.andvari.net/webhooks/nomad-botherer`

**Update the variable:**
```bash
bash scripts/nomad-var-set.sh nomad/jobs/homelab-webhook github_webhook_secret "$NEW_SECRET"
```

The webhook job restarts. GitHub retries failed deliveries, so no events are
lost during the brief restart window.

### grafana_admin_password

Keep this in sync with `nomad/jobs/grafana`. See the
[Grafana section](#grafana-admin-credentials-and-database-password-nomadjosgrafana)
for the correct order (change in Grafana first).

```bash
bash scripts/nomad-var-set.sh nomad/jobs/homelab-webhook grafana_admin_password NEW_PW_HERE
```

### nomad_token (nomad-botherer)

Same rotation procedure as the Traefik nomad_token. The policy for
nomad-botherer needs `namespace:read` and `job:read`.

```bash
bash scripts/nomad-var-set.sh nomad/jobs/homelab-webhook nomad_token NEW_TOKEN_HERE
```

---

## Miniflux database password (`nomad/jobs/miniflux`)

**Keys:** `postgres_pass`

**Generate and change in PostgreSQL first:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
bash scripts/pg-connect.sh
ALTER USER miniflux WITH PASSWORD 'NEW_PW_HERE';
\q
```

**Update the variable:**
```bash
bash scripts/nomad-var-set.sh nomad/jobs/miniflux postgres_pass NEW_PW_HERE
```

---

## Kutt database password and JWT secret (`nomad/jobs/kutt`)

**Keys:** `postgres_pass`, `jwt_secret`

### postgres_pass

**Generate and change in PostgreSQL first:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
bash scripts/pg-connect.sh
ALTER USER kutt WITH PASSWORD 'NEW_PW_HERE';
\q

bash scripts/nomad-var-set.sh nomad/jobs/kutt postgres_pass NEW_PW_HERE
```

### jwt_secret

Rotating this invalidates all active user sessions (everyone gets logged out).

**Generate and update:**
```bash
NEW_JWT=$(openssl rand -hex 64)
bash scripts/nomad-var-set.sh nomad/jobs/kutt jwt_secret "$NEW_JWT"
```

---

## Immich database password (`nomad/jobs/immich`)

**Keys:** `db_password`

Immich bundles its own PostgreSQL instance (port 5433 on the allocation). The
same `db_password` is used by both the `immich-db` task and the `immich-server`
task.

**Generate:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW
```

**Change the password inside the running immich-db container first:**
```bash
ALLOC=$(nomad job status immich | grep running | awk '{print $1}')
nomad alloc exec -task immich-db $ALLOC \
  psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'NEW_PW_HERE';"
```

**Update the variable:**
```bash
bash scripts/nomad-var-set.sh nomad/jobs/immich db_password NEW_PW_HERE
```

Both tasks restart. `immich-db` restarts first; `immich-server` reconnects with
the new password.

---

## Cringesweeper social media credentials (`nomad/jobs/cringesweeper`)

**Keys:** `bluesky_user`, `bluesky_password`, `mastodon_user`,
`mastodon_instance`, `mastodon_access_token`

### bluesky_password

Change at *bsky.app → Settings → Privacy and Security → Change Password*, then:

```bash
bash scripts/nomad-var-set.sh nomad/jobs/cringesweeper bluesky_password NEW_PW_HERE
```

### mastodon_access_token

Revoke and regenerate at *[your instance] → Settings → Applications →
[cringesweeper app] → Regenerate*, then:

```bash
bash scripts/nomad-var-set.sh nomad/jobs/cringesweeper mastodon_access_token NEW_TOKEN_HERE
```

---

## Mosquitto MQTT password file (`nomad/jobs/mosquitto`)

**Keys:** `passwd`

The `passwd` key holds the entire contents of a `mosquitto_passwd` formatted
file (one `user:hash` entry per line). All MQTT client credentials live here,
including the credentials used by `nut2mqtt`.

**Generate a new hashed entry** on a host with `mosquitto-passwd` installed:
```bash
# Create a new passwd file (or edit the existing one)
mosquitto_passwd -c /tmp/mqtt_passwd MQTT_USERNAME
# enter new password when prompted

# For additional users, append without -c
mosquitto_passwd -b /tmp/mqtt_passwd user2 password2
```

**Update the variable** (the entire file content as a single value):
```bash
bash scripts/nomad-var-set.sh nomad/jobs/mosquitto passwd "$(cat /tmp/mqtt_passwd)"
```

Mosquitto restarts and loads the new password file. **Update `nut2mqtt`
immediately after** or MQTT publishing from the UPS monitor will fail.

---

## nut2mqtt MQTT credentials (`nomad/jobs/nut2mqtt`)

**Keys:** `mqtt_user`, `mqtt_pass`

These must match an entry in the Mosquitto password file. Rotate these in the
same operation as mosquitto to minimise downtime.

```bash
bash scripts/nomad-var-set.sh nomad/jobs/nut2mqtt mqtt_user NEW_USER
bash scripts/nomad-var-set.sh nomad/jobs/nut2mqtt mqtt_pass NEW_PASSWORD
```

---

## Newt / Pangolin tunnel (`nomad/jobs/newt`)

**Keys:** `endpoint`, `id`, `secret`

`id` and `secret` are issued by the Pangolin server. Rotate them in the
Pangolin dashboard under *Sites → [site] → Credentials → Regenerate*.

```bash
bash scripts/nomad-var-set.sh nomad/jobs/newt id NEW_ID
bash scripts/nomad-var-set.sh nomad/jobs/newt secret NEW_SECRET
```

The Newt client restarts and re-establishes the tunnel. Expect a few seconds of
tunnel downtime.

---

## Birdnet location (`nomad/jobs/birdnet`)

**Keys:** `latitude`, `longitude`

Not secrets in the security sense — location coordinates for the bird audio
analyser. Update if the physical device moves.

```bash
bash scripts/nomad-var-set.sh nomad/jobs/birdnet latitude NEW_LAT
bash scripts/nomad-var-set.sh nomad/jobs/birdnet longitude NEW_LON
```
