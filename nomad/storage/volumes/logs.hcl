id        = "logs"
name      = "logs"
type      = "csi"
plugin_id = "rabbitseason-mix-nfs"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}
