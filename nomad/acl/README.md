# nomad/acl

Nomad ACL policy definitions.

| Policy | Purpose |
|---|---|
| `variable-admin-policy.hcl` | Read/write access to all Nomad variables in all namespaces |
| `traefik-policy.hcl` | Read access to the default namespace service catalog for Traefik routing |
| `traefik-vars-policy.hcl` | Read access to `cloud_dns_key` for Traefik's workload identity |
| `nomad-botherer-policy.hcl` | List, read, and plan jobs in the default namespace (for nomad-botherer drift detection) |
| `databasus-vars-policy.hcl` | Read access to `nomad/jobs/postgres` and `nomad/jobs/mysql` for Databasus's workload identity |

## Prerequisites: workload identity auth method

Binding rules (used by workload identities) require a JWT auth method named
`nomad-workloads` to exist. Create it once per cluster:

```bash
nomad acl auth-method create \
  -name=nomad-workloads \
  -type=JWT \
  -max-token-ttl=30m \
  -token-locality=local \
  -config='{
    "JWKSURL": "http://127.0.0.1:4646/.well-known/jwks.json",
    "BoundAudiences": ["nomad.io"],
    "ClaimMappings": {
      "nomad_job_id": "nomad_job_id",
      "nomad_namespace": "nomad_namespace",
      "nomad_task": "nomad_task"
    }
  }'
```

## Applying policies and creating tokens

```bash
# databasus-vars: allows databasus workload identity to read postgres/mysql credentials
nomad acl policy apply -description "Databasus variable access" databasus-vars nomad/acl/databasus-vars-policy.hcl
nomad acl binding-rule create \
  -auth-method=nomad-workloads \
  -bind-type=policy \
  -bind-name=databasus-vars \
  -selector='value.nomad_job_id == "databasus"'

# variable-admin: used for bootstrapping/managing Nomad variables
nomad acl policy apply -description "variable admin" variable-admin variable-admin-policy.hcl
nomad acl token create -name="variable reader/writer" -policy=variable-admin

# traefik: allows Traefik's Nomad provider to read the service catalog
nomad acl policy apply -description "Traefik service catalog reader" traefik traefik-policy.hcl
nomad acl token create -name="traefik" -policy=traefik
# Store the Secret ID in: nomad var put nomad/jobs/traefik nomad_token=<id>

# nomad-botherer: list, read, and plan jobs for drift detection
# Note: Nomad has no plan-only capability -- submit-job covers both planning
# and submitting. nomad-botherer only plans, but the token technically could submit.
nomad acl policy apply -description "nomad-botherer job drift detector" nomad-botherer nomad-botherer-policy.hcl
nomad acl token create -name="nomad-botherer" -policy=nomad-botherer
# Store the Secret ID in: nomad var put nomad/jobs/homelab-webhook nomad_token=<id>
```

See `backpack.sh` for the bootstrap sequence that runs these on a fresh cluster.
