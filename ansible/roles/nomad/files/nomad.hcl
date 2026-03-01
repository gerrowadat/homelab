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
    allow_privileged = true
    volumes {
      enabled = true 
    }
  }
}
plugin "raw_exec" {
  config {
    enabled = true
  }
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics = true
}
