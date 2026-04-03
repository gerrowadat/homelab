id = "birdnet" # ID as seen in nomad
name = "birdnet" # Display name
type = "csi"
plugin_id = "rabbitseason-srv-nfs"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}
