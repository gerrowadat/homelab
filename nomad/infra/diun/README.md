# diun

Runs [Diun](https://github.com/crazy-max/diun) (Docker Image Update Notifier),
which polls container registries for new tags of images the cluster runs and
keeps a record of what it has seen.

Uses Diun's **Nomad provider** with `watchByDefault: true`: every running
Docker-driver task in the cluster is watched, no per-job opt-in meta needed.
Checks run every 6 hours.

## Notifications

**None configured yet — deliberately.** The plan (see
`docs/proposals/diun-integration.md` in the nomad-botherer repo) is for Diun
to POST a webhook to nomad-botherer, which records available image updates
and serves ready-to-apply HCL patches. nomad-botherer 0.3.1 does not yet
implement that intake, so for now found updates are only visible in Diun's
logs:

```bash
nomad alloc logs -job diun diun
```

Diun notifies each new tag **once** and remembers it in its state db
(`/local/diun.db`, ephemeral task disk). When the webhook notifier is added
later, the db being lost on reschedule is harmless — everything is
re-notified once and the receiver deduplicates.

## Nomad variables

Reads from `nomad/jobs/diun`. Create before deploying:

```bash
nomad var put nomad/jobs/diun nomad_token=<acl-token>
```

| Key           | Required | Description                                              |
|---------------|----------|----------------------------------------------------------|
| `nomad_token` | yes      | Nomad ACL token — see `nomad/acl/diun-policy.hcl`        |

Create the policy and token:

```bash
nomad acl policy apply -description "Diun read access" diun nomad/acl/diun-policy.hcl
nomad acl token create -name=diun -policy=diun -type=client
```

## Monitoring

Diun exposes no Prometheus metrics, so monitoring is Nomad-level:

- `DiunNotRunning` (`monitoring/diun_alerting_rules.yml`) — warns when the
  job has no running allocation (or the job disappears entirely) for 15
  minutes.
- Crash-loops and resource pressure are covered by the generic
  `NomadTaskFlapping` / `nomad-resources` alerts.

Whether registry checks are actually succeeding is not observable until the
nomad-botherer webhook intake ships and provides receiver-side metrics
(`nomad_botherer_diun_webhooks_received_total` etc., per the proposal).

## Deployment

```bash
nomad job run nomad/infra/diun/diun.hcl
```
