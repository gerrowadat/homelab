# nomad/apps

User-facing applications.

| Job | What it is | Notes |
|---|---|---|
| `hass` | Home Assistant | Pinned to `hedwig` (local SSD, Zigbee coordinator) |
| `z2m` | Zigbee2MQTT | Pinned to `picluster5` (Conbee USB stick attached there) |
| `octoprint` | 3D printer web UI + webcam streamer | Pinned to `picluster5` (printer USB attached there) |
| `miniflux` | RSS reader | Backed by postgres |
| `birdnet` | BirdNET-Pi bird call detection | Backed by CSI NFS volume |
| `giv_tcp` | GivEnergy solar inverter monitoring | Talks to inverter at fixed LAN IP |
| `cringesweeper` | Sweeps old posts from Bluesky and Mastodon | Secrets in `nomad/jobs/cringesweeper` |

## Hardware-pinned jobs

Several jobs are pinned to specific hosts via hostname constraints because they
need access to locally attached USB devices. If a device moves to a different host,
update the `constraint` block in the job file.
