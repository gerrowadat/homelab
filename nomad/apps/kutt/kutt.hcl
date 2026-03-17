job "kutt" {
  datacenters = ["home"]

  group "kutt_servers" {

    volume "kutt" {
      type            = "csi"
      source          = "kutt"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "kutt_server" {
      driver = "docker"

      service {
        name = "kutt"
        port = "kutt"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.kutt.rule=Host(`go.home.andvari.net`)",
          "traefik.http.routers.kutt.tls=true",
          "traefik.http.routers.kutt.tls.certresolver=le",
          "traefik.http.routers.kutt.middlewares=internal-only@file",
        ]
        check {
          name     = "HTTP Connection Check"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      template {
        data = <<EOF
DEFAULT_DOMAIN=go.home.andvari.net
PORT=3000
DB_CLIENT=pg
DB_HOST=postgres.service.home.consul
DB_PORT=5432
DB_NAME=kutt
DB_USER=kutt
DB_PASSWORD={{ with nomadVar "nomad/jobs/kutt" }}{{ .postgres_pass }}{{ end }}
JWT_SECRET={{ with nomadVar "nomad/jobs/kutt" }}{{ .jwt_secret }}{{ end }}
MAIL_HOST=postfix-andvari-smarthost.service.home.consul
MAIL_PORT=25
MAIL_FROM=kutt@home.andvari.net
MAIL_SECURE=false
EOF
        destination = "secrets/env"
        env         = true
      }

      config {
        image = "docker.io/kutt/kutt:latest"
        ports = ["kutt"]
      }

      volume_mount {
        volume      = "kutt"
        destination = "/data"
      }

      resources {
        cpu    = 256
        memory = 256
      }
    }

    network {
      mode = "host"
      port "kutt" {
        static = "3000"
      }
    }
  }
}
