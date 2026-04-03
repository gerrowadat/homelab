id        = "mosquitto"
name      = "mosquitto"
type      = "csi"
plugin_id = "rabbitseason-srv-nfs"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}
