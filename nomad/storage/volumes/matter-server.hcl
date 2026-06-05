id = "matter-server"
name = "matter-server"
type = "csi"
plugin_id = "rabbitseason-srv-nfs"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}
