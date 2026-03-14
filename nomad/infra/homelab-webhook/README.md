# homelab-webhook

Nomad job that receives GitHub push webhooks and acts on changes to this repo.
Contains two task groups, each handling a distinct concern.

---

## Tasks

### `homelab-webhook_servers` — monitoring reload

A lightweight Python webhook server (`webhook.py`) that watches for changes to
`monitoring/` files. On a matching push to `main`:

1. Runs `git pull` on the `gitrepo` CSI volume (shared read-write mount).
2. POSTs `/-/reload` to Prometheus, Alertmanager, and Blackbox Exporter.

Listens on port **9111**. Traefik routes `POST /webhooks/monitoring-reload` to
this service.

### `nomad-botherer` — Nomad job drift detection

Runs [nomad-botherer](https://github.com/gerrowadat/nomad-botherer), which
watches the `nomad/` directory of this repo for HCL job definitions and
compares them against what's actually running in Nomad.

On a webhook push (or on its polling interval), it:

1. Fetches the latest `main` branch of the homelab repo.
2. Parses every `.hcl` file under `nomad/`.
3. Compares parsed definitions against live Nomad jobs.
4. Reports drift (modified, missing from Nomad, or missing from repo) via
   `GET /diffs` and `GET /healthz`.

Listens on port **9112**. Traefik routes `POST /webhooks/nomad-botherer` to
this service (no `internal-only` middleware — GitHub must be able to reach it).

Must run on a Nomad **server** node so it can talk to the local Nomad API.
Constrained to amd64 — the only non-server node in the cluster is the
Raspberry Pi (arm64).

---

## Nomad variables

Both tasks read from `nomad/jobs/homelab-webhook`. Create or update the
variable before deploying:

```bash
nomad var put nomad/jobs/homelab-webhook \
  github_webhook_secret=<secret> \
  nomad_token=<optional-acl-token>
```

| Key                    | Required | Description                                              |
|------------------------|----------|----------------------------------------------------------|
| `github_webhook_secret` | yes     | HMAC secret configured in the GitHub webhook settings    |
| `nomad_token`           | no      | Nomad ACL token for nomad-botherer (omit if ACL disabled) — see `nomad/acl/` |

---

## GitHub webhook setup

Configure **two** webhooks in the GitHub repo settings
(`Settings → Webhooks → Add webhook`), both pointing at `https://home.andvari.net`:

| Payload URL                                      | Events       |
|--------------------------------------------------|--------------|
| `https://home.andvari.net/webhooks/monitoring-reload` | Push    |
| `https://home.andvari.net/webhooks/nomad-botherer`    | Push    |

Use the same secret (`github_webhook_secret`) for both. Set content type to
`application/json`.

---

## Deployment

```bash
# Deploy the webhook job
nomad job run nomad/infra/homelab-webhook/homelab-webhook.hcl

# Redeploy Traefik to pick up the new /webhooks/nomad-botherer route
nomad job run nomad/infra/traefik/traefik.hcl
```

---

## Checking nomad-botherer output

```bash
# Drift report (plain text)
curl https://home.andvari.net/diffs         # via Traefik (not yet routed — hit directly)
curl http://nomad-botherer.service.home.consul:9112/diffs

# Health / drift summary (JSON)
curl http://nomad-botherer.service.home.consul:9112/healthz

# Prometheus metrics
curl http://nomad-botherer.service.home.consul:9112/metrics

# Logs
nomad alloc logs -job homelab-webhook nomad-botherer
```

> **Note:** `LOG_LEVEL=debug` is set while the integration is being validated.
> Lower it to `info` once things look stable by removing the `LOG_LEVEL` line
> from the template in `homelab-webhook.hcl`.
