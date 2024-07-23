job "miniflux" {
  datacenters = ["home"]
  group "miniflux_servers" {
    task "miniflux_server" {
      template {
        //data = "{{ with nomadVar \"nomad/jobs/miniflux\" }}{{ .env }}{{ end }}"
        data = <<EOF
DATABASE_URL=postgres://miniflux:{{ with nomadVar "nomad/jobs/miniflux" }}{{ .postgres_pass }}{{ end }}@postgres.home.nomad.andvari.net/miniflux?sslmode=disable
RUN_MIGRATIONS=1
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
        static = "8080"
      }
    }
  }
}
