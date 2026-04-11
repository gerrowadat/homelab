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
        # Traefik routing is defined in nomad/infra/traefik/traefik.hcl
        # (dynamic.yml template), keyed off kutt_hostname in nomad/jobs/traefik.
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
        image = "docker.io/kutt/kutt:v3.2.3"
        ports = ["kutt"]
      }

      volume_mount {
        volume      = "kutt"
        destination = "/data"
      }

      resources {
        cpu    = 100
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
