job "victorialogs" {
  datacenters = ["home"]

  meta {
    gitops_managed = "true"
    gitops_update_policy = "full"
  }

  group "victorialogs" {

    update {
      auto_revert = true
      health_check = "checks"
    }

    volume "logs" {
      type            = "csi"
      source          = "logs"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    network {
      port "http" {
        static = 9428
      }
    }

    task "victorialogs" {
      driver = "docker"

      config {
        image = "victoriametrics/victoria-logs:v1.50.0"
        args  = [
          "-storageDataPath=/data",
          "-retentionPeriod=30d",
          "-httpListenAddr=:9428",
        ]
        ports = ["http"]
      }

      volume_mount {
        volume      = "logs"
        destination = "/data"
      }

      service {
        name = "logs"
        port = "http"
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.logs.rule=Host(`logs.home.andvari.net`)",
          "traefik.http.routers.logs.tls=true",
          "traefik.http.routers.logs.tls.certresolver=le",
          "traefik.http.routers.logs.middlewares=internal-only@file",
        ]
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }
}
