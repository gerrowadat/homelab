id        = "mysqlbackup"
name      = "mysqlbackup"
type      = "csi"
plugin_id = "rabbitseason-mix-nfs"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}
