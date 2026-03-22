# postfix-andvari-smarthost

Internal Postfix relay. Accepts SMTP from the local network
(`192.168.100.0/24`) and forwards mail to `mx.andvari.net`.

This allows cluster services (Alertmanager, cron jobs, etc.) to send email
without each needing its own outbound mail config.

## Configuration

| Setting | Value |
|---|---|
| Listens on | port 25 (all interfaces) |
| Accepts from | `192.168.100.0/24`, `172.17.0.0/24` |
| Relays to | `mx.andvari.net` |
| Local domain | `home.andvari.net` |

No Nomad variable required — all config is in the job's `env` block.

## Usage

Point other services at `postfix-andvari-smarthost.service.home.consul:25`
as their SMTP relay.

## Deployment

```bash
nomad job run nomad/infra/postfix-andvari-smarthost/postfix-andvari-smarthost.hcl
```
