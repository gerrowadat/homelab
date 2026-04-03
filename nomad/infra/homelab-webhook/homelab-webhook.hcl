job "homelab-webhook" {
  datacenters = ["home"]
  type        = "service"

  group "homelab-webhook_servers" {

    volume "gitrepo" {
      type            = "csi"
      source          = "gitrepo"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    // docker image is only built for x86 et. al.
    constraint {
      attribute = "${attr.cpu.arch}"
      operator  = "="
      value     = "amd64"
    }

    task "homelab-webhook_server" {
      driver = "docker"

      config {
        image   = "python:3.12.13-alpine"
        command = "/bin/sh"
        args    = ["-c", "apk add --no-cache git su-exec && cp /gitrepo/nomad/infra/homelab-webhook/webhook.py /local/webhook.py && exec su-exec nobody python /local/webhook.py"]
        ports   = ["homelab-webhook"]
        dns_search_domains = ["home.andvari.net"]
      }

      volume_mount {
        volume      = "gitrepo"
        destination = "/gitrepo"
      }

      template {
        destination = "secrets/env"
        env         = true
        data        = <<EOF
GITHUB_WEBHOOK_SECRET={{ with nomadVar "nomad/jobs/homelab-webhook" }}{{ .github_webhook_secret }}{{ end }}
GRAFANA_ADMIN_USER={{ with nomadVar "nomad/jobs/homelab-webhook" }}{{ .grafana_admin_user }}{{ end }}
GRAFANA_ADMIN_PASSWORD={{ with nomadVar "nomad/jobs/homelab-webhook" }}{{ .grafana_admin_password }}{{ end }}
EOF
      }

      service {
        name = "homelab-webhook"
        port = "homelab-webhook"
        check {
          name     = "TCP health check"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    network {
      mode = "host"
      port "homelab-webhook" {
        static = "9111"
      }
    }
  }

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
WEBHOOK_SECRET={{ with nomadVar "nomad/jobs/homelab-webhook" }}{{ .github_webhook_secret }}{{ end }}
NOMAD_TOKEN={{ with nomadVar "nomad/jobs/homelab-webhook" }}{{ .nomad_token }}{{ end }}
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
