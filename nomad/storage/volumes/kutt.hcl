id = "kutt" # ID as seen in nomad
name = "kutt" # Display name
type = "csi"
plugin_id = "rabbitseason-srv-nfs" # Needs to match the deployed plugin

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}
