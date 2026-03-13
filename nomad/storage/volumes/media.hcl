id = "media" # ID as seen in nomad
name = "Media" # Display name
type = "csi"
plugin_id = "rabbitseason-mix-nfs" # Needs to match the deployed plugin

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}
