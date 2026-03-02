# traefik

Traefik is the ingress and SSL termination layer for the cluster. It replaces
the previous nginx + certbot + letsencrypt-to-nomad-vars setup.

It uses the native Nomad service provider, so any job can opt into routing just
by adding tags to its `service` block — no separate nginx config or cert plumbing.

## How it works

- Traefik runs on `hedwig`, owning ports 80 and 443.
- Port 80 redirects everything to HTTPS.
- TLS certificates are obtained automatically via Let's Encrypt DNS-01 challenge
  using the GCP Cloud DNS service account in the `cloud_dns_key` Nomad variable.
- `acme.json` (the cert store) lives at `/localssd/traefik/acme.json` on hedwig's
  local SSD, persisting across container restarts.
- Traefik discovers services by reading the Nomad service catalog. Jobs opt in
  with `traefik.enable=true` tags.
- Services not managed as Nomad jobs (sonarr, radarr, etc.) are routed via the
  file provider in the `dynamic.yml` template inside `traefik.hcl`.

---

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

### 3. Grant Traefik access to cloud_dns_key

Nomad's workload identity gives jobs automatic read access to variables under
`nomad/jobs/<jobname>`. The GCP credentials live at `cloud_dns_key` (a top-level
path), so access must be granted explicitly. Two options:

**Option A — ACL binding rule (recommended: keeps the key in one place)**

```bash
# Apply the variable-access policy
nomad acl policy apply \
  -description "Traefik variable access" \
  traefik-vars \
  nomad/acl/traefik-vars-policy.hcl

# Bind the policy to the traefik job's workload identity
nomad acl binding-rule create \
  -auth-method=nomad-workloads \
  -bind-type=policy \
  -bind-name=traefik-vars \
  "-selector=${value.nomad_job_id} == \"traefik\""
```

This requires the `nomad-workloads` auth method to be configured on the cluster
(it is present by default in Nomad 1.7+). After this, the traefik job's workload
identity token will automatically include the `traefik-vars` policy and can read
`cloud_dns_key` in its template blocks.

**Option B — Copy the key into nomad/jobs/traefik (simpler, no binding rules)**

If workload identity auth methods aren't set up, just store the key under the
path the job can already access:

```bash
nomad var put nomad/jobs/traefik \
  gcp_credentials_json="$(cat /path/to/gcp-service-account.json)" \
  ...
```

Then update the template block in `traefik.hcl` that reads `cloud_dns_key` to
read `.gcp_credentials_json` from `nomad/jobs/traefik` instead.

### 4. Set the Nomad variables

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

### 5. Deploy

```bash
nomad job run nomad/infra/traefik/traefik.hcl
```

Check the dashboard at `http://hedwig:8080` (LAN only) to confirm routes and
certificates are loading correctly.

---

## Playbook

### Add a route for a Nomad-managed service

Add tags to the job's `service` block and redeploy the job:

```hcl
service {
  name = "myapp"
  port = "http"
  tags = [
    "traefik.enable=true",
    "traefik.http.routers.myapp.rule=Host(`myapp.home.andvari.net`)",
    "traefik.http.routers.myapp.tls=true",
    "traefik.http.routers.myapp.tls.certresolver=le",
    # omit this line to make the route publicly accessible
    "traefik.http.routers.myapp.middlewares=internal-only@file",
  ]
}
```

Traefik picks up the new service immediately. Also add a DNS record pointing
the hostname at hedwig (`192.168.100.250`), or a CNAME to `hedwig.home.andvari.net.`
in `dns/home.andvari.net.zone`.

### Add a route for an externally-managed service

Edit the `dynamic.yml` template in `traefik.hcl` and add a router + service pair:

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

Then redeploy the Traefik job:

```bash
nomad job run nomad/infra/traefik/traefik.hcl
```

Consul DNS names (`*.service.home.consul`) work as backend URLs because Traefik
runs in host network mode and resolves via the local Consul-aware DNS.

### Check certificate status

Open the dashboard at `http://hedwig:8080` and go to **HTTPS** → certificates,
or inspect `acme.json` directly:

```bash
ssh hedwig "cat /localssd/traefik/acme.json | python3 -m json.tool | grep -A2 'domain'"
```

Traefik renews certificates automatically when they are within 30 days of expiry.
No manual action is normally needed.

### Force certificate renewal

Traefik renews automatically, but if you need to force it (e.g. after a DNS
change or to recover a broken cert):

```bash
# Stop Traefik, remove the cert entry from acme.json, restart.
nomad job stop traefik
ssh hedwig "cat /localssd/traefik/acme.json | python3 -c \"
import sys, json
d = json.load(sys.stdin)
# Remove the specific cert -- Traefik will re-request it on next start
for resolver in d.values():
    resolver.get('Certificates', [])[:] = [
        c for c in resolver.get('Certificates', [])
        if 'yourdomain.com' not in str(c.get('domain', ''))
    ]
print(json.dumps(d, indent=2))
\" > /tmp/acme-new.json && mv /tmp/acme-new.json /localssd/traefik/acme.json"
nomad job run nomad/infra/traefik/traefik.hcl
```

Or to force renewal of all certs at once, remove `acme.json` entirely and
redeploy — but be mindful of [Let's Encrypt rate limits](https://letsencrypt.org/docs/rate-limits/)
(5 duplicate cert requests per week per domain).

### Upgrade Traefik

Edit the image tag in `traefik.hcl`:

```hcl
image = "traefik:v3.x"
```

Then redeploy:

```bash
nomad job run nomad/infra/traefik/traefik.hcl
```

Check the [Traefik migration guide](https://doc.traefik.io/traefik/migration/v2-to-v3/)
before jumping major versions.

### Move Traefik to a different host

1. Copy `acme.json` to the same path on the new host:
   ```bash
   scp hedwig:/localssd/traefik/acme.json newhost:/localssd/traefik/acme.json
   ```
2. Update the `constraint` in `traefik.hcl` to the new hostname.
3. Redeploy.

**Do not skip copying `acme.json`** — if it's missing, Traefik re-requests all
certs from scratch and you may hit Let's Encrypt rate limits.

### Debug routing problems

- Dashboard at `http://hedwig:8080` shows all routers, services, and middlewares
  and whether they are healthy.
- Check Traefik logs:
  ```bash
  nomad alloc logs <alloc-id>
  ```
- To find the current allocation ID:
  ```bash
  nomad job status traefik
  ```
- Set `level: DEBUG` in the `log` section of `traefik.yml` temporarily for
  verbose output, then redeploy.

---

## IP restriction

The `internal-only@file` middleware restricts access to `192.168.100.0/24`.
Apply it to any router that should not be reachable from the internet.
To make a route fully public, omit the `middlewares` tag/key entirely.
