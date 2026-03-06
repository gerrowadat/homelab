# nomad

Nomad job definitions for everything running on the cluster.

## Layout

| Directory | Contents |
|---|---|
| `apps/` | User-facing applications |
| `infra/` | Infrastructure services (databases, web, MQTT, DNS, certs, email) |
| `monitoring/` | Prometheus, Alertmanager, and exporters |
| `storage/` | CSI plugin (NFS) and volume definitions |
| `cron/` | Periodic batch jobs |
| `acl/` | Nomad ACL policies |

## Secrets

Secrets are stored in Nomad variables and injected into jobs via `template` blocks:

```hcl
template {
  data = <<EOH
{{- with nomadVar "nomad/jobs/myjob" -}}
MY_SECRET={{ .some_key }}
{{- end -}}
EOH
  destination = "secrets/env"
  env         = true
}
```

Variables must be created manually before deploying a job that needs them:

```bash
nomad var put nomad/jobs/myjob some_key=value
```

The `nomad/jobs/<jobname>` path is the convention used throughout.

## Datacenter

All jobs target datacenter `"home"`. This matches the `datacenter = "home"` in
the Consul and Nomad agent configs deployed by Ansible.
