# octoprint

[OctoPrint](https://octoprint.org/) — web interface for the 3D printer,
with MJPG webcam streaming enabled.

Pinned to `picluster5` — the Pi physically attached to the printer via USB.

## Hardware access

The job runs in `privileged` mode with host networking, which is required
for reliable USB serial (`/dev/ttyACM0`) and video (`/dev/video0`) device
access. These are passed through as `/dev/printer` and `/dev/video0`
inside the container.

## Storage

Bind-mounted from `/things/docker/octoprint` (NFS share from duckseason).

## Networking

Listens on port 80 inside the container, exposed on the host at port 8888.
Reachable at `octoprint.service.home.consul:8888` from within the cluster.
No Traefik route — access is direct via Consul DNS.

## Deployment

```bash
nomad job run nomad/apps/octoprint/octoprint.hcl
```
