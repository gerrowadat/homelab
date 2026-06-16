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

      // Ensure stdout is never block-buffered, so reload/pull logs reach
      // `nomad alloc logs` immediately even if a future webhook.py drops the
      // explicit flush. Without this, log output can sit unflushed and a
      // failed reload looks like silence.
      env {
        PYTHONUNBUFFERED = "1"
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

}
