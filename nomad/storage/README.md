# nomad/storage

CSI storage plugin and volume definitions.

## Plugin: rocketduck NFS

`rocketduck-controller.hcl` and `rocketduck-node.hcl` deploy the
[csi-plugin-nfs](https://gitlab.com/rocketduck/csi-plugin-nfs) from rocketduck.

The controller job runs as a single instance; the node job runs as `type = "system"`
(i.e. one instance on every Nomad client). Both need `network_mode = "host"` and
`privileged = true` so that NFS mounts survive container lifecycle events.

The NFS server is `tings` (the QNAP NAS), exporting `/srv`. Plugin ID is
`tings-srv-nfs` — this must match between controller, node, and volume definitions.

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
