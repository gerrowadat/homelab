job "esphome" {
  datacenters = ["home"]

  group "esphome" {
    volume "esphome" {
      type            = "csi"
      source          = "esphome"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "esphome" {
      driver = "docker"

      service {
        name = "esphome"
        port = "http"
        check {
          name     = "HTTP"
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "5s"
        }
      }

      config {
        image = "ghcr.io/esphome/esphome:2025.5.0"
        ports = ["http"]
      }

      volume_mount {
        volume      = "esphome"
        destination = "/config"
      }

      resources {
        cpu        = 500
        memory     = 512
        memory_max = 1024
      }
    }

    network {
      mode = "host"
      port "http" { static = 6052 }
    }
  }
}
