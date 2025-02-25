id = "telly" # ID as seen in nomad
name = "telly" # Display name
type = "csi"
plugin_id = "tings-srv-nfs" # Needs to match the deployed plugin

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}
