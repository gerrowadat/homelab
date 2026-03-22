# newt

[Newt](https://docs.fossorial.io/Pangolin/Tunnels/newt) — tunnel client for
[Pangolin](https://github.com/fosrl/pangolin), providing remote access to
homelab services without exposing ports directly.

Runs with `distinct_hosts = true`, meaning one instance per Nomad node
(currently count = 1, so it lands on one host).

Exposes a Prometheus metrics endpoint at port 2112.

## Nomad variable

`nomad/jobs/newt` must contain:

| Key | Description |
|---|---|
| `endpoint` | Pangolin server URL |
| `id` | Newt client ID |
| `secret` | Newt client secret |

```bash
nomad var put nomad/jobs/newt endpoint="https://..." id="..." secret="..."
```

## Deployment

```bash
nomad job run nomad/infra/newt/newt.hcl
```
