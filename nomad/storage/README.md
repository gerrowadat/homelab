# nomad/storage

CSI storage plugin and volume definitions.

## Plugin: rocketduck NFS

`rocketduck-controller.hcl` and `rocketduck-node.hcl` deploy the
[csi-plugin-nfs](https://gitlab.com/rocketduck/csi-plugin-nfs) from rocketduck.

The controller job runs as a single instance; the node job runs as `type = "system"`
(i.e. one instance on every Nomad client). Both need `network_mode = "host"` and
`privileged = true` so that NFS mounts survive container lifecycle events.

Three plugins are deployed, each backed by a different NFS server/export:

| Plugin ID | Files | NFS server |
|---|---|---|
| `tings-srv-nfs` | `rocketduck-{controller,node}.hcl` | `tings:/srv` (QNAP NAS) |
| `rabbitseason-srv-nfs` | `rabbitseason-srv-nfs-{controller,node}.hcl` | `rabbitseason:/srv` |
| `rabbitseason-mix-nfs` | `rabbitseason-mix-nfs-{controller,node}.hcl` | `rabbitseason:/mix` |

Plugin ID must match between controller, node, and any volume definitions that use it.

## Volumes

Volume definitions live in `volumes/`. Each `.hcl` file defines a named CSI volume
that jobs can claim with a `volume` block:

```hcl
volume "mydata" {
  type            = "csi"
  source          = "mydata"
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}
```

Volumes are created once with `nomad volume create volumes/mydata.hcl` and then
persist independently of job deployments.
