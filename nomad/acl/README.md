# nomad/acl

Nomad ACL policy definitions.

| Policy | Purpose |
|---|---|
| `variable-admin-policy.hcl` | Read/write access to all Nomad variables in all namespaces |
| `traefik-policy.hcl` | Read access to the default namespace service catalog for Traefik routing |

## Applying policies and creating tokens

```bash
# variable-admin: used for bootstrapping/managing Nomad variables
nomad acl policy apply -description "variable admin" variable-admin variable-admin-policy.hcl
nomad acl token create -name="variable reader/writer" -policy=variable-admin

# traefik: allows Traefik's Nomad provider to read the service catalog
nomad acl policy apply -description "Traefik service catalog reader" traefik traefik-policy.hcl
nomad acl token create -name="traefik" -policy=traefik
# Store the Secret ID in: nomad var put nomad/jobs/traefik nomad_token=<id>
```

See `backpack.sh` for the bootstrap sequence that runs these on a fresh cluster.
