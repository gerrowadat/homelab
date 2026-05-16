# homelab-webhook

Nomad job that receives GitHub push webhooks and acts on changes to the
`monitoring/` directory of this repo.

---

## Task

### `homelab-webhook_servers` — monitoring reload

A lightweight Python webhook server (`webhook.py`) that watches for changes to
`monitoring/` files. On a matching push to `main`:

1. Runs `git pull` on the `gitrepo` CSI volume (shared read-write mount).
2. If any `monitoring/` files changed (excluding `monitoring/grafana/`): POSTs
   `/-/reload` to Prometheus, Alertmanager, and Blackbox Exporter.
3. If any `monitoring/grafana/` files changed: POSTs the Grafana provisioning
   reload API (`/api/admin/provisioning/datasources/reload` and
   `/api/admin/provisioning/dashboards/reload`) using Basic auth.

Listens on port **9111**. Traefik routes `POST /webhooks/monitoring-reload` to
this service.

---

## Nomad variables

Reads from `nomad/jobs/homelab-webhook`. Create or update before deploying:

```bash
nomad var put nomad/jobs/homelab-webhook \
  github_webhook_secret=<secret> \
  grafana_admin_user=<grafana-admin-username> \
  grafana_admin_password=<grafana-admin-password>
```

| Key                      | Required | Description                                              |
|--------------------------|----------|----------------------------------------------------------|
| `github_webhook_secret`  | yes      | HMAC secret configured in the GitHub webhook settings    |
| `grafana_admin_user`     | yes      | Grafana admin username (must match `nomad/jobs/grafana`) |
| `grafana_admin_password` | yes      | Grafana admin password (must match `nomad/jobs/grafana`) |

---

## GitHub webhook setup

Configure a webhook in the GitHub repo settings
(`Settings → Webhooks → Add webhook`):

| Payload URL                                           | Events |
|-------------------------------------------------------|--------|
| `https://home.andvari.net/webhooks/monitoring-reload` | Push   |

Set content type to `application/json`.

---

## Deployment

```bash
nomad job run nomad/infra/homelab-webhook/homelab-webhook.hcl
```
