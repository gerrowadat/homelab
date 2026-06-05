job "matter-server" {
  datacenters = ["home"]

  meta {
    gitops_managed = "true"
  }

  group "matter-server" {
    volume "matter-server" {
      type            = "csi"
      source          = "matter-server"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "matter-server" {
      driver = "docker"

      service {
        name = "matter-server"
        port = "ws"
        check {
          name     = "TCP"
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }

      config {
        image        = "ghcr.io/home-assistant-libs/python-matter-server:8.1.0"
        ports        = ["ws"]
        args         = ["--storage-path", "/data"]
        security_opt = ["apparmor=unconfined"]
      }

      volume_mount {
        volume      = "matter-server"
        destination = "/data"
      }

      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }
    }

    network {
      mode = "host"
      port "ws" { static = 5580 }
    }
  }
}
