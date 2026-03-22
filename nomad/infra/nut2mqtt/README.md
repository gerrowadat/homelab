# nut2mqtt

[nut2mqtt](https://github.com/gerrowadat/nut2mqtt) — polls UPS status from
NUT daemons (`upsd`) running on UPS-attached hosts and publishes the data to
MQTT for consumption by Home Assistant and monitoring.

Reads from `duckseason` (the host on the networking UPS). Publishes to
`mosquitto.service.home.consul` under the `nut2mqtt/` topic prefix.

Exposes an HTTP endpoint at port 3494 (Consul-registered as `nut2mqtt`).

## Nomad variable

`nomad/jobs/nut2mqtt` must contain:

| Key | Description |
|---|---|
| `mqtt_user` | MQTT broker username |
| `mqtt_pass` | MQTT broker password |

```bash
nomad var put nomad/jobs/nut2mqtt mqtt_user="..." mqtt_pass="..."
```

## Deployment

```bash
nomad job run nomad/infra/nut2mqtt/nut2mqtt.hcl
```
