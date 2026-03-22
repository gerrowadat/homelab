# birdnet

[BirdNET-Go](https://github.com/tphakala/birdnet-go) — real-time bird call
detection and identification from audio input.

Available at `https://birbs.home.andvari.net` (internal network only).

## Storage

Uses the `birdnet` CSI NFS volume mounted at both `/config` and `/data`.

## Nomad variable

`nomad/jobs/birdnet` must contain:

| Key | Value |
|---|---|
| `latitude` | Decimal latitude for local species filtering |
| `longitude` | Decimal longitude for local species filtering |

```bash
nomad var put nomad/jobs/birdnet latitude="53.3" longitude="-6.2"
```

## Deployment

```bash
nomad job run nomad/apps/birdnet/birdnet.hcl
```

The job runs the `nightly` tag of BirdNET-Go. It consumes 2 CPU cores and
2 GB RAM — resource-heavy due to ML inference.
