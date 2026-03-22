# z2m

[Zigbee2MQTT](https://www.zigbee2mqtt.io/) — bridges Zigbee devices to MQTT
via a ConBee II USB stick attached to `picluster5`.

Pinned to `picluster5` via a hostname constraint.

## Hardware access

The job runs in `privileged` mode to access the ConBee USB serial device
(`/dev/ttyACM*`). The udev socket is mounted read-only so the container can
detect the device path. The process runs as `nobody:dialout` — unprivileged
except for the `dialout` group membership needed for serial access.

## Storage

Bind-mounted from `/things/docker/z2m` (NFS share from duckseason). This
contains Zigbee2MQTT's configuration (`configuration.yaml`) and the Zigbee
device database.

## Networking

Reachable at `z2m.service.home.consul:8081`. No Traefik route — this is
an internal-only service.

## Deployment

```bash
nomad job run nomad/infra/z2m/z2m.hcl
```
