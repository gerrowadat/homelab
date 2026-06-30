# nomad-botherer

Runs [nomad-botherer](https://github.com/gerrowadat/nomad-botherer), which
watches the `nomad/` directory of this repo for HCL job definitions and
compares them against what's actually running in Nomad (drift detection).

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

Reads from `nomad/jobs/nomad-botherer`. Create or update before deploying:

```bash
nomad var put nomad/jobs/nomad-botherer \
  github_webhook_secret=<secret>
```

| Key                     | Required | Description                                                      |
|-------------------------|----------|------------------------------------------------------------------|
| `github_webhook_secret` | yes      | HMAC secret configured in the GitHub webhook settings            |

## Nomad access (workload identity)

This job authenticates to the Nomad API with its **default workload identity**,
not a static token. The task's `identity { file = true }` block makes Nomad
write a short-lived, auto-renewed ACL token to `${NOMAD_SECRETS_DIR}/nomad_token`,
which nomad-botherer (>= 0.9.0) auto-detects. Capabilities come from the
`nomad-botherer` policy **associated with this job** — see
`nomad/acl/README.md`. No `nomad_token` variable is needed; if one lingers from
the old setup it is unused and the static token can be deleted.

---

## GitHub webhook setup

Configure a webhook in the GitHub repo settings
(`Settings → Webhooks → Add webhook`):

| Payload URL                                        | Events |
|----------------------------------------------------|--------|
| `https://home.andvari.net/webhooks/nomad-botherer` | Push   |

Set content type to `application/json`.

---

## Deployment

```bash
nomad job run nomad/infra/nomad-botherer/nomad-botherer.hcl
```

---

## Checking output

```bash
# Drift report
curl http://nomad-botherer.service.home.consul:9112/diffs

# Health / drift summary (JSON)
curl http://nomad-botherer.service.home.consul:9112/healthz

# Prometheus metrics
curl http://nomad-botherer.service.home.consul:9112/metrics

# Logs
nomad alloc logs -job nomad-botherer nomad-botherer
```

> **Note:** `LOG_LEVEL=debug` is set while the integration is being validated.
> Lower it to `info` once things look stable by removing the `LOG_LEVEL` line
> from the template in `nomad-botherer.hcl`.
