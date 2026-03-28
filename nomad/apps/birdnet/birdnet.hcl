job "birdnet" {
  datacenters = ["home"]
  group "birdnet_servers" {

    volume "birdnet" {
      type = "csi"
      source = "birdnet"
      read_only = false
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }

    task "birdnet_server" {
      service {
        name = "birdnet"
        port = "birdnet"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.birdnet.rule=Host(`birbs.home.andvari.net`)",
          "traefik.http.routers.birdnet.tls=true",
          "traefik.http.routers.birdnet.tls.certresolver=le",
          "traefik.http.routers.birdnet.middlewares=internal-only@file",
        ]
        check {
          name = "HTTP Connection Check"
          type = "http"
          path = "/"
          interval = "10s"
          timeout = "2s"
        }
      }
      template {
        data = <<EOF
BIRDNET_LATITUDE={{ with nomadVar "nomad/jobs/birdnet" }}{{ .latitude }}{{ end }}
BIRDNET_LONGITUDE={{ with nomadVar "nomad/jobs/birdnet" }}{{ .longitude }}{{ end }}
EOF
        destination = "secrets/birdnet_env"
        env = true
      }
      driver = "docker" 
      config {
        image = "ghcr.io/tphakala/birdnet-go:nightly"
        ports = ["birdnet"]
      }
      volume_mount {
        volume = "birdnet"
        destination = "/config"
      }
      volume_mount {
        volume = "birdnet"
        destination = "/data"
      }
      resources {
        cpu    = 1200
        memory = 1024
      }
    }
    network {
      mode = "host"
      port "birdnet" {
        static = "8823"
      }
    }
  }
}
