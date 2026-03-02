# traefik

Traefik is the ingress and SSL termination layer for the cluster. It replaces
the previous nginx + certbot + letsencrypt-to-nomad-vars setup.

It uses the native Nomad service provider, so any job can opt into routing just
by adding tags to its `service` block — no nginx config to edit, no cert plumbing.

## How it works

- Traefik runs on `hedwig`, owning ports 80 and 443.
- Port 80 redirects everything to HTTPS.
- TLS certificates are obtained automatically via Let's Encrypt DNS-01 challenge
  using the GCP Cloud DNS service account in the `cloud_dns_key` Nomad variable.
- `acme.json` (the cert store) lives at `/localssd/traefik/acme.json` on hedwig's
  local SSD, persisting across container restarts.
- Traefik discovers services by reading the Nomad service catalog. Services opt in
  with `traefik.enable=true` tags.

## Bootstrap (first-time setup)

### 1. Create the data directory on hedwig

```bash
ssh hedwig mkdir -p /localssd/traefik
```

### 2. Create the Nomad ACL policy and token

```bash
nomad acl policy apply -description "Traefik service catalog reader" traefik nomad/acl/traefik-policy.hcl
nomad acl token create -name="traefik" -policy=traefik
# Save the Secret ID from the output
```

### 3. Set the Nomad variables

```bash
nomad var put nomad/jobs/traefik \
  acme_email=you@example.com \
  gce_project=your-gcp-project-id \
  nomad_token=<Secret ID from step 2>
```

`gce_project` must match the GCP project that owns the `home.andvari.net` DNS zone.
`cloud_dns_key` should already exist from the old certbot setup; if not:

```bash
nomad var put cloud_dns_key json=@/path/to/gcp-service-account.json
```

### 4. Deploy

```bash
nomad job run nomad/infra/traefik/traefik.hcl
```

Check the dashboard at `http://hedwig:8080` (LAN only).

## Exposing a service through Traefik

Add tags to the job's `service` block:

```hcl
service {
  name = "myapp"
  port = "http"
  tags = [
    "traefik.enable=true",
    "traefik.http.routers.myapp.rule=Host(`myapp.home.andvari.net`)",
    "traefik.http.routers.myapp.tls=true",
    "traefik.http.routers.myapp.tls.certresolver=le",
    # omit the middleware line to make the service publicly accessible
    "traefik.http.routers.myapp.middlewares=internal-only@file",
  ]
}
```

Traefik will request a certificate for `myapp.home.andvari.net` automatically
the first time a request arrives. Also add a DNS record pointing the hostname
at hedwig (`192.168.100.250`), or a CNAME to `hedwig.home.andvari.net.`.

## IP restriction

The `internal-only@file` middleware restricts access to `192.168.100.0/24`.
Apply it to any router that should not be reachable from the internet.
To make something fully public, omit the `middlewares` tag.

## For services not managed as Nomad jobs (sonarr, radarr, etc.)

Services that can't carry their own Traefik tags (externally managed, or running
outside Nomad) are routed via the file provider in the `dynamic.yml` template
inside `traefik.hcl`. Add a router and service entry there:

```yaml
routers:
  myapp:
    rule: "Host(`home.andvari.net`) && PathPrefix(`/myapp`)"
    tls:
      certResolver: le
    middlewares: [internal-only]
    service: myapp

services:
  myapp:
    loadBalancer:
      servers:
        - url: "http://myapp.service.home.consul:1234"
```

Redeploy the Traefik job after editing to pick up the change. Consul DNS names
(`*.service.home.consul`) work as backend URLs because Traefik runs in host
network mode and resolves via the local Consul-aware DNS.

## Moving Traefik to a different host

1. Copy `/localssd/traefik/acme.json` to the same path on the new host.
2. Update the `constraint` in `traefik.hcl` to the new hostname.
3. Redeploy. **Do not skip copying acme.json** — if it's missing, Traefik will
   re-request all certs from scratch and you may hit Let's Encrypt rate limits.
