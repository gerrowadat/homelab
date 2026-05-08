# Secret Rotation Runbook

## How Nomad variable rotation works

Secrets live in Nomad variables at `nomad/jobs/<jobname>`. Jobs read them via
`template` blocks. When a variable changes, Nomad detects it and applies the
template's `change_mode` — the default is `restart`, so the affected task
restarts automatically within a few seconds. Only `prometheus` has an explicit
`change_mode = "restart"` annotation; all others rely on this default.

**`nomad var put` replaces all keys.** Always read the current variable first,
then write back all keys — including the ones you are not changing.

```bash
# Safe update pattern
nomad var get nomad/jobs/<jobname>   # note every key and its current value
nomad var put nomad/jobs/<jobname> \
  unchanged_key=existing_value \
  rotating_key=NEW_VALUE
```

**Database password rotations require the password to be changed in the
database first.** The `POSTGRES_PASSWORD` / `MYSQL_ROOT_PASSWORD` env vars
only apply on first container initialisation; they do not change an existing
database's credentials. Change the password in the DB, then update the Nomad
variable.

---

## PostgreSQL root password (`nomad/jobs/postgres`)

**Keys:** `pgpassword`

**Generate a new password:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW   # save this before proceeding
```

**Change the password in the running database:**
```bash
bash scripts/pg-connect.sh
# then inside psql:
ALTER USER postgres WITH PASSWORD 'NEW_PW_HERE';
\q
```

**Update the Nomad variable:**
```bash
nomad var put nomad/jobs/postgres pgpassword=NEW_PW_HERE
```

Postgres will restart automatically. The data directory already has the new
password; the restart is harmless.

**Verify:**
```bash
nomad job status postgres
bash scripts/pg-connect.sh   # confirm connection works with new password
```

---

## MySQL root password (`nomad/jobs/mysql`)

**Keys:** `root_password`

**Generate a new password:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW
```

**Change the password in the running database:**
```bash
bash scripts/mysql-connect.sh
# then inside mysql:
ALTER USER 'root'@'%' IDENTIFIED BY 'NEW_PW_HERE';
FLUSH PRIVILEGES;
exit
```

**Update the Nomad variable:**
```bash
nomad var put nomad/jobs/mysql root_password=NEW_PW_HERE
```

MySQL restarts automatically. The data directory retains the new password.

**Verify:**
```bash
nomad job status mysql
bash scripts/mysql-connect.sh
```

---

## Grafana admin credentials and database password (`nomad/jobs/grafana`)

**Keys:** `grafana_admin_user`, `grafana_admin_password`, `grafana_db_password`

These are three distinct secrets that must be rotated separately.

### grafana_admin_password

Grafana stores its own admin password in its database, independently of the
env var. Change the password in Grafana first, then update the variable so the
two stay in sync.

```bash
# Change via Grafana API (or through the web UI under Profile → Change Password)
curl -X PUT \
  -H "Content-Type: application/json" \
  -u admin:CURRENT_PASSWORD \
  -d '{"oldPassword":"CURRENT_PASSWORD","newPassword":"NEW_PW","confirmNew":"NEW_PW"}' \
  http://grafana.service.home.consul:3000/api/user/password
```

**Generate a new password:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW
```

**Update the variable (preserve all three keys):**
```bash
nomad var get nomad/jobs/grafana   # note current values
nomad var put nomad/jobs/grafana \
  grafana_admin_user=admin \
  grafana_admin_password=NEW_PW_HERE \
  grafana_db_password=EXISTING_DB_PW
```

### grafana_db_password

This is the password for the `grafana` user in the main PostgreSQL instance.

**Generate a new password:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW
```

**Change it in PostgreSQL first:**
```bash
bash scripts/pg-connect.sh
ALTER USER grafana WITH PASSWORD 'NEW_PW_HERE';
\q
```

**Update the variable:**
```bash
nomad var put nomad/jobs/grafana \
  grafana_admin_user=EXISTING_USER \
  grafana_admin_password=EXISTING_ADMIN_PW \
  grafana_db_password=NEW_PW_HERE
```

Grafana restarts automatically and reconnects with the new password.

---

## Prometheus / Grafana Cloud credentials (`nomad/jobs/prometheus`)

**Keys:** `grafana_metrics_host`, `grafana_stack_id`, `grafana_metrics_read_token`

These credentials authenticate Prometheus's `remote_read` against Grafana Cloud.
`grafana_stack_id` is your Grafana Cloud numeric stack ID (username) and does
not change. Only `grafana_metrics_read_token` needs rotation.

**Generate a new token:**
In the Grafana Cloud portal: *My Account → Stack → Access Policies → Create
token* (scope: `metrics:read`). Note the token value — it is shown only once.

**Update the variable:**
```bash
nomad var get nomad/jobs/prometheus   # note all three current values
nomad var put nomad/jobs/prometheus \
  grafana_metrics_host=EXISTING_HOST \
  grafana_stack_id=EXISTING_ID \
  grafana_metrics_read_token=NEW_TOKEN_HERE
```

Prometheus has `change_mode = "restart"` on this template. It restarts
automatically, reconnects to Grafana Cloud, and resumes remote_read.

**Verify:**
```bash
nomad job status prometheus
# check Prometheus UI → Status → Configuration for the remote_read stanza
curl -s http://prometheus.service.home.consul:9090/-/healthy
```

---

## Traefik — GCP DNS credentials and Nomad token (`nomad/jobs/traefik`)

**Keys:** `gcp_credentials_json`, `gce_project`, `acme_email`, `nomad_token`,
and optional routing helpers (`home_ip`, `birdnet_hostname`, `kutt_hostname`,
`immich_hostname`, `paperless_hostname`).

### gcp_credentials_json (ACME DNS-01 challenge)

This is a GCP service account key used by lego/Traefik for DNS-01 certificate
renewal against Cloud DNS.

Rotate in the GCP console:
1. *IAM & Admin → Service Accounts → [traefik-acme account] → Keys → Add Key*
2. Download the new JSON key.
3. Delete the old key.

**Update the variable** (the JSON must be on one line or quoted appropriately):
```bash
NEW_CREDS=$(cat new-key.json | tr -d '\n')
nomad var get nomad/jobs/traefik   # note all other existing values

nomad var put nomad/jobs/traefik \
  gcp_credentials_json="$NEW_CREDS" \
  gce_project=EXISTING_PROJECT \
  acme_email=EXISTING_EMAIL \
  nomad_token=EXISTING_TOKEN
  # add optional keys if set
```

Traefik restarts. Existing ACME certificates in `/localssd/traefik/acme.json`
are not affected; the new credentials are only used at next renewal.

### nomad_token (Traefik Nomad provider)

The Traefik Nomad provider uses this token to read the service catalog.

**Create a new token** (policy must allow `namespace:read`):
```bash
nomad acl token create -name=traefik-provider \
  -policy=traefik-policy \
  | grep 'Secret ID' | awk '{print $4}'
```

**Update the variable:**
```bash
nomad var put nomad/jobs/traefik \
  gcp_credentials_json=EXISTING_JSON \
  gce_project=EXISTING \
  acme_email=EXISTING \
  nomad_token=NEW_TOKEN_HERE
```

**Revoke the old token** once Traefik has restarted and is healthy:
```bash
nomad acl token list   # find old token accessor ID
nomad acl token delete <accessor_id>
```

---

## homelab-webhook (`nomad/jobs/homelab-webhook`)

**Keys:** `github_webhook_secret`, `grafana_admin_user`, `grafana_admin_password`,
`nomad_token`

### github_webhook_secret

This is the HMAC secret used to verify GitHub push webhook payloads.

**Generate:**
```bash
NEW_SECRET=$(openssl rand -hex 32)
echo $NEW_SECRET
```

**Update in GitHub** (must be done before or simultaneously with the Nomad var,
since GitHub signs new deliveries immediately):
*GitHub repo → Settings → Webhooks → [webhook URL] → Edit → Secret → paste new
value → Update webhook.*

Do this for both webhook URLs:
- `https://home.andvari.net/webhooks/monitoring-reload`
- `https://home.andvari.net/webhooks/nomad-botherer`

**Update the Nomad variable:**
```bash
nomad var get nomad/jobs/homelab-webhook
nomad var put nomad/jobs/homelab-webhook \
  github_webhook_secret=NEW_SECRET_HERE \
  grafana_admin_user=EXISTING \
  grafana_admin_password=EXISTING \
  nomad_token=EXISTING
```

The webhook job restarts; during the brief restart window GitHub may send a
delivery that gets a non-200 response. GitHub retries failed deliveries, so no
events are lost.

### grafana_admin_user / grafana_admin_password

These shadow the credentials in `nomad/jobs/grafana` so the webhook can call
Grafana's reload API. Keep them in sync with the `nomad/jobs/grafana` values.
See the [Grafana section](#grafana-admin-credentials-and-database-password-nomadjosgrafana) above for how to change the Grafana password first.

### nomad_token (nomad-botherer)

Same rotation procedure as the Traefik nomad_token above. The policy for
nomad-botherer only needs `namespace:read` and `job:read`.

---

## Miniflux database password (`nomad/jobs/miniflux`)

**Keys:** `postgres_pass`

Miniflux connects as the `miniflux` user in the main PostgreSQL instance.

**Generate:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW
```

**Change in PostgreSQL first:**
```bash
bash scripts/pg-connect.sh
ALTER USER miniflux WITH PASSWORD 'NEW_PW_HERE';
\q
```

**Update the variable:**
```bash
nomad var put nomad/jobs/miniflux postgres_pass=NEW_PW_HERE
```

Miniflux restarts and reconnects.

---

## Kutt database password and JWT secret (`nomad/jobs/kutt`)

**Keys:** `postgres_pass`, `jwt_secret`

### postgres_pass

**Generate and change in PostgreSQL first:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW

bash scripts/pg-connect.sh
ALTER USER kutt WITH PASSWORD 'NEW_PW_HERE';
\q
```

### jwt_secret

Rotating the JWT secret invalidates all active user sessions (everyone gets
logged out).

**Generate:**
```bash
NEW_JWT=$(openssl rand -hex 64)
echo $NEW_JWT
```

**Update both keys together:**
```bash
nomad var put nomad/jobs/kutt \
  postgres_pass=NEW_PW_HERE \
  jwt_secret=NEW_JWT_HERE
```

Kutt restarts. Users will need to log in again.

---

## Immich database password (`nomad/jobs/immich`)

**Keys:** `db_password`

Immich bundles its own PostgreSQL instance (port 5433 on the Nomad allocation).
The `db_password` is used by both the `immich-db` task (`POSTGRES_PASSWORD`)
and the `immich-server` task (`DB_PASSWORD`).

**Generate:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
echo $NEW_PW
```

**Find the allocation and change the password inside immich-db:**
```bash
ALLOC=$(nomad job status immich | grep running | awk '{print $1}')

nomad alloc exec -task immich-db $ALLOC \
  psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'NEW_PW_HERE';"
```

**Update the Nomad variable:**
```bash
nomad var put nomad/jobs/immich db_password=NEW_PW_HERE
```

Both tasks restart. `immich-db` restarts first; `immich-server` reconnects with
the new password.

---

## Paperless database password, secret key, and admin credentials (`nomad/jobs/paperless`)

**Keys:** `db_password`, `secret_key`, `admin_user`, `admin_password`, `hostname`

### db_password

**Generate and change in PostgreSQL first:**
```bash
NEW_PW=$(openssl rand -base64 24 | tr -d '/+=')
bash scripts/pg-connect.sh
ALTER USER paperless WITH PASSWORD 'NEW_PW_HERE';
\q
```

### secret_key

This is Django's `SECRET_KEY`. Rotating it invalidates all active sessions and
CSRF tokens. It also affects any data encrypted with this key (check Paperless
docs for your version before rotating).

**Generate:**
```bash
NEW_KEY=$(openssl rand -hex 64)
echo $NEW_KEY
```

### admin_password

Change via the Paperless web UI (*Admin → Users → [admin user] → Change
Password*) or via the Django management command:

```bash
ALLOC=$(nomad job status paperless | grep running | awk '{print $1}')
nomad alloc exec $ALLOC \
  python3 manage.py changepassword ADMIN_USERNAME_HERE
```

**Update all keys together:**
```bash
nomad var get nomad/jobs/paperless
nomad var put nomad/jobs/paperless \
  db_password=NEW_DB_PW \
  secret_key=NEW_SECRET_KEY \
  admin_user=EXISTING_USER \
  admin_password=NEW_ADMIN_PW \
  hostname=EXISTING_HOSTNAME
```

---

## Cringesweeper social media credentials (`nomad/jobs/cringesweeper`)

**Keys:** `bluesky_user`, `bluesky_password`, `mastodon_user`,
`mastodon_instance`, `mastodon_access_token`

### bluesky_password

Change at *bsky.app → Settings → Privacy and Security → Change Password*.

### mastodon_access_token

Revoke and regenerate at *[your instance] → Settings → Applications →
[cringesweeper app] → Regenerate*.

**Update the variable:**
```bash
nomad var get nomad/jobs/cringesweeper
nomad var put nomad/jobs/cringesweeper \
  bluesky_user=EXISTING \
  bluesky_password=NEW_BLUESKY_PW \
  mastodon_user=EXISTING \
  mastodon_instance=EXISTING \
  mastodon_access_token=NEW_TOKEN_HERE
```

---

## Mosquitto MQTT password file (`nomad/jobs/mosquitto`)

**Keys:** `passwd`

The `passwd` key holds the entire contents of a `mosquitto_passwd` formatted
file (hashed passwords, one `user:hash` entry per line). All MQTT client
credentials are encoded here, including the password used by `nut2mqtt`.

**Generate a new hashed entry** on a host with `mosquitto-passwd` installed:
```bash
# Create a new passwd file with one user
mosquitto_passwd -c /tmp/mqtt_passwd MQTT_USERNAME
# Enter new password when prompted

# Print the resulting hash line to paste into the variable
cat /tmp/mqtt_passwd
```

For multiple users, add them with `-b` (batch mode) or omit `-c` to append:
```bash
mosquitto_passwd -b /tmp/mqtt_passwd user2 password2
```

**Update the variable** (the entire file content as a single string):
```bash
PASSWD_CONTENT=$(cat /tmp/mqtt_passwd)
nomad var put nomad/jobs/mosquitto passwd="$PASSWD_CONTENT"
```

Mosquitto restarts and loads the new password file. **Update `nut2mqtt`
immediately after** (see below) or MQTT publishing from the UPS monitor will
fail.

---

## nut2mqtt MQTT credentials (`nomad/jobs/nut2mqtt`)

**Keys:** `mqtt_user`, `mqtt_pass`

These must match an entry in the Mosquitto password file above.

```bash
nomad var put nomad/jobs/nut2mqtt \
  mqtt_user=NEW_USER \
  mqtt_pass=NEW_PASSWORD
```

Rotate this in the same operation as mosquitto to minimise downtime.

---

## Newt / Pangolin tunnel (`nomad/jobs/newt`)

**Keys:** `endpoint`, `id`, `secret`

`id` and `secret` are issued by the Pangolin server. Rotate them in the
Pangolin dashboard under *Sites → [site] → Credentials → Regenerate*.

```bash
nomad var put nomad/jobs/newt \
  endpoint=EXISTING_ENDPOINT \
  id=NEW_ID \
  secret=NEW_SECRET
```

The Newt client restarts and re-establishes the tunnel. Expect a few seconds of
tunnel downtime.

---

## Birdnet location (`nomad/jobs/birdnet`)

**Keys:** `latitude`, `longitude`

Not secrets in the security sense — location coordinates for the bird audio
analyser. Update if the physical device moves.

```bash
nomad var put nomad/jobs/birdnet \
  latitude=NEW_LAT \
  longitude=NEW_LON
```
