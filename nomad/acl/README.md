# nomad/acl

Nomad ACL policy definitions.

| Policy | Purpose |
|---|---|
| `variable-admin-policy.hcl` | Read/write access to all Nomad variables in all namespaces |
| `traefik-policy.hcl` | Read access to the default namespace service catalog for Traefik routing |
| `traefik-vars-policy.hcl` | Read access to `cloud_dns_key` for Traefik's workload identity |
| `nomad-gitops-policy.hcl` | List, read, plan, and mutate jobs in the default namespace; mount CSI volumes (namespace `csi-mount-volume` + top-level `plugin` read); read all `nomad/jobs/*` variables (for nomad-gitops drift detection and job reconciliation) |

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
# variable-admin: used for bootstrapping/managing Nomad variables
nomad acl policy apply -description "variable admin" variable-admin variable-admin-policy.hcl
nomad acl token create -name="variable reader/writer" -policy=variable-admin

# traefik: allows Traefik's Nomad provider to read the service catalog
nomad acl policy apply -description "Traefik service catalog reader" traefik traefik-policy.hcl
nomad acl token create -name="traefik" -policy=traefik
# Store the Secret ID in: nomad var put nomad/jobs/traefik nomad_token=<id>

# nomad-gitops: list, read, plan, and mutate jobs; mount CSI volumes; read variables.
# Uses workload identity via the ACL login exchange (nomad-gitops >= 0.9.1) --
# no static token. The job has a named identity `nomad-api` (aud "nomad.io"); on
# login the binding rule below grants it the nomad-gitops policy. A raw WI JWT
# cannot be used directly (Nomad's Job.Plan rejects it), hence the exchange.
nomad acl policy apply -description "nomad-gitops job drift detector" nomad-gitops nomad-gitops-policy.hcl
nomad acl binding-rule create \
  -auth-method nomad-workloads -bind-type policy \
  -bind-name nomad-gitops \
  -selector 'value.nomad_job_id == "nomad-gitops"'
```

The `nomad-workloads` JWT auth method (see the top of this file) must exist, and
its `bound_audiences` (`nomad.io`) must match the job's `identity` block `aud`.

See `backpack.sh` for the bootstrap sequence that runs these on a fresh cluster.
