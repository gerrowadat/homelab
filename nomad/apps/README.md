# nomad/apps

User-facing applications.

| Job | What it is | Notes |
|---|---|---|
| `octoprint` | 3D printer web UI + webcam streamer | Pinned to `picluster5` (printer USB attached there) |
| `miniflux` | RSS reader | Backed by postgres; path-based route at `/rss` |
| `birdnet` | BirdNET-Go bird call detection | Backed by CSI NFS volume; at `birbs.home.andvari.net` |
| `cringesweeper` | Sweeps old posts from Bluesky and Mastodon | Secrets in `nomad/jobs/cringesweeper` |
| `kutt` | URL shortener at go.home.andvari.net | Backed by postgres and CSI NFS volume; secrets in `nomad/jobs/kutt` |
| `immich` | Self-hosted photo/video management | Dedicated postgres+vectorchord, Redis, ML; photos on mix, DB on srv |
| `esphome` | ESPHome dashboard for ESP8266/ESP32 firmware | Config on srv CSI volume; OTA-only (no USB); at `esphome.service.home.consul:6052` |
| `hass` | Home Assistant home automation hub | Postgres recorder (no SQLite on NFS); at `hass.home.andvari.net` |
| `matter-server` | python-matter-server WebSocket backend for HA | HA connects to `matter-server.service.home.consul:5580`; device state on NFS volume |

## Hardware-pinned jobs

Several jobs are pinned to specific hosts via hostname constraints because they
need access to locally attached USB devices. If a device moves to a different host,
update the `constraint` block in the job file.
