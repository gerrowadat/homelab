job "grafana" {
  datacenters = ["home"]

  group "grafana_servers" {

    volume "grafana" {
      type            = "csi"
      source          = "grafana"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "gitrepo" {
      type            = "csi"
      source          = "gitrepo"
      read_only       = true
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    network {
      port "grafana" {
        static = 3000
      }
    }

    task "grafana_server" {
      driver = "docker"

      # Grafana configuration via environment variables.
      # grafana_admin_user / grafana_admin_password: initial admin credentials.
      # grafana_db_password: password for the 'grafana' Postgres user.
      # Database must be created before first deploy — see docs/grafana.md.
      template {
        destination = "secrets/grafana.env"
        env         = true
        data        = <<EOH
GF_SECURITY_ADMIN_USER={{ with nomadVar "nomad/jobs/grafana" }}{{ .grafana_admin_user }}{{ end }}
GF_SECURITY_ADMIN_PASSWORD={{ with nomadVar "nomad/jobs/grafana" }}{{ .grafana_admin_password }}{{ end }}
GF_DATABASE_TYPE=postgres
GF_DATABASE_HOST=postgres.service.home.consul:5432
GF_DATABASE_NAME=grafana
GF_DATABASE_USER=grafana
GF_DATABASE_PASSWORD={{ with nomadVar "nomad/jobs/grafana" }}{{ .grafana_db_password }}{{ end }}
GF_DATABASE_SSL_MODE=disable
GF_SERVER_ROOT_URL=https://home.andvari.net/graphs/
GF_SERVER_SERVE_FROM_SUB_PATH=true
GF_PATHS_PROVISIONING=/config/monitoring/grafana/provisioning
GF_AUTH_ANONYMOUS_ENABLED=false
EOH
      }

      config {
        image = "grafana/grafana:11.4.0"
        ports = ["grafana"]
        dns_search_domains = ["home.andvari.net"]
      }

      volume_mount {
        volume      = "grafana"
        destination = "/var/lib/grafana"
      }

      volume_mount {
        volume      = "gitrepo"
        destination = "/config"
      }

      service {
        name = "grafana"
        port = "grafana"
        check {
          type     = "http"
          path     = "/graphs/api/health"
          interval = "10s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
