job "miniflux" {
  datacenters = ["home"]
  group "miniflux_servers" {
    task "miniflux_server" {
      service {
        name = "miniflux"
        port = "miniflux"
        check {
          name = "HTTP Connection Check"
          type = "http"
          path = "/rss/healthcheck"
          interval = "10s"
          timeout = "2s"
        }
      }
      template {
        data = <<EOF
DATABASE_URL=postgres://miniflux:{{ with nomadVar "nomad/jobs/miniflux" }}{{ .postgres_pass }}{{ end }}@postgres.service.home.consul/miniflux?sslmode=disable
RUN_MIGRATIONS=1
BASE_URL=https://home.andvari.net/rss
EOF
        destination = "secrets/miniflux_env"
        env = true
      }
      driver = "docker" 
      config {
        image = "docker.io/miniflux/miniflux:latest"
        ports = ["miniflux"]
      }
    }
    network {
      mode = "host"
      port "miniflux" {
        static = "8822"
        to = "8080"
      }
      dns {
        servers = ["192.168.100.250", "192.168.100.251", "192.168.100.253"]
      }
    }
  }
}
