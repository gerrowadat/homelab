job "nomad-botherer" {
  datacenters = ["home"]
  type        = "service"

  group "nomad-botherer" {

    // amd64 constraint also ensures this runs on a Nomad server node --
    // the only non-server in the cluster is the Raspberry Pi (arm64).
    constraint {
      attribute = "${attr.cpu.arch}"
      operator  = "="
      value     = "amd64"
    }

    task "nomad-botherer" {
      driver = "docker"

      config {
        image = "ghcr.io/gerrowadat/nomad-botherer:0.0.2"
        ports = ["nomad-botherer"]
      }

      template {
        destination = "secrets/env"
        env         = true
        data        = <<EOF
GIT_REPO_URL=https://github.com/gerrowadat/homelab
GIT_BRANCH=main
HCL_DIR=nomad
LISTEN_ADDR=:9112
WEBHOOK_PATH=/webhooks/nomad-botherer
NOMAD_ADDR=http://nomad.service.home.consul:4646
LOG_LEVEL=debug
WEBHOOK_SECRET={{ with nomadVar "nomad/jobs/nomad-botherer" }}{{ .github_webhook_secret }}{{ end }}
NOMAD_TOKEN={{ with nomadVar "nomad/jobs/nomad-botherer" }}{{ .nomad_token }}{{ end }}
EOF
      }

      service {
        name = "nomad-botherer"
        port = "nomad-botherer"
        check {
          name     = "HTTP health check"
          type     = "http"
          path     = "/healthz"
          interval = "30s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    network {
      mode = "host"
      port "nomad-botherer" {
        static = "9112"
      }
    }
  }
}
