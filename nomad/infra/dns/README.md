# dns

BIND9 DNS server that forwards `.consul` queries to the local Consul agent,
allowing cluster-internal DNS resolution (`<service>.service.home.consul`)
to work for any host that uses this server as its resolver.

This is separate from the authoritative DNS for `home.andvari.net` (see
`dns/` at the repo root for those zone files).

## Deployment

```bash
nomad job run nomad/infra/dns/dns.hcl
```
