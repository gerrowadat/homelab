id = "pgbackup" # ID as seen in nomad
name = "pgbackup" # Display name
type = "csi"
plugin_id = "rabbitseason-mix-nfs" # Needs to match the deployed plugin

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}
