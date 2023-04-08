datacenter = "home"
data_dir = "/opt/nomad"
acl {
  enabled = true
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
