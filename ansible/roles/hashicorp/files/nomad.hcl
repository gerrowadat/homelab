datacenter = "home"
data_dir = "/opt/nomad"
acl {
  enabled = true
}
consul {
  address = "127.0.0.1:8500"
}
plugin "docker" {
  config {
    # Required for jobs that need hardware device access (octoprint, z2m, CSI storage plugin).
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}
# raw_exec allows running commands directly on the host without a container.
# Used by the letsencrypt-to-nomad-vars job and other infra tasks that need
# host-level access.
plugin "raw_exec" {
  config {
    enabled = true
  }
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics = true
}
