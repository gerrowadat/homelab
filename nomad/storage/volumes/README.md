# nomad/storage/volumes

CSI NFS volume definitions. Each file describes one volume — its name,
capacity, access mode, and NFS mount parameters.

## Volumes

| Volume | Used by |
|---|---|
| `birdnet` | birdnet job (`/config`, `/data`) |
| `databasus` | databasus job (database dump storage) |
| `gitrepo` | Most jobs (read-only); homelab-webhook (read-write). Mounted at `/config`. |
| `grafana` | grafana job (provisioning, plugins) |
| `jellyfin` | Defined; no active job in this repo |
| `kutt` | kutt job |
| `media` | Shared media storage |
| `monitoring` | prometheus (TSDB), alertmanager (state) |
| `immich-photos` | immich job (photo/video library at `/usr/src/app/upload`) |
| `immich-db` | immich job (postgres data directory) |
| `mysql` | mysql job (`/var/lib/mysql`) |

Note: postgres uses a local SSD bind-mount (`/localssd/postgres` on `hedwig`)
rather than a CSI volume, to avoid the performance overhead of NFS for a
database workload.

## Creating a volume

```bash
nomad volume create nomad/storage/volumes/<name>.hcl
```

All volumes use the `nfs-controller` plugin defined in `nomad/storage/`.
The NFS server is `rabbitseason`.
