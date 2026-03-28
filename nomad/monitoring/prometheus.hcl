job "prometheus" {
  datacenters = ["home"]
  group "prometheus_servers" {

    volume "monitoring" {
      type = "csi"
      source = "monitoring"
      read_only = false
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }

    volume "gitrepo" {
      type = "csi"
      source = "gitrepo"
      read_only = true
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }

    task "prometheus_server" {
      service {
	      name = "prometheus"
	      port = "prometheus"
      }
      driver = "docker"

      # Grafana Cloud remote_read credentials from nomad/jobs/prometheus.
      # Written to /local/remote_read.yml and concatenated with the gitrepo
      # prometheus.yml at startup by /local/start.sh.
      # change_mode=restart ensures Prometheus picks up credential rotations.
      template {
        data = <<EOH
remote_read:
  - url: "https://{{ with nomadVar "nomad/jobs/prometheus" }}{{ .grafana_metrics_host }}{{ end }}/api/prom/api/v1/read"
    basic_auth:
      username: "{{ with nomadVar "nomad/jobs/prometheus" }}{{ .grafana_stack_id }}{{ end }}"
      password: "{{ with nomadVar "nomad/jobs/prometheus" }}{{ .grafana_metrics_read_token }}{{ end }}"
    read_recent: true
EOH
        destination = "local/remote_read.yml"
        change_mode = "restart"
      }

      # Startup script: concatenate the gitrepo prometheus.yml with the
      # remote_read section, then exec Prometheus against the combined file.
      # Alert rule files are loaded from /config/monitoring/ (gitrepo) so
      # /-/reload still picks up rule changes pushed via the webhook.
      template {
        data = <<EOH
#!/bin/sh
set -e
cat /config/monitoring/prometheus.yml /local/remote_read.yml > /local/prometheus.yml
exec /bin/prometheus \
  --config.file=/local/prometheus.yml \
  --storage.tsdb.path=/data/prometheus/prom-tsdb/ \
  --web.external-url=http://prometheus.service.home.consul:9090/ \
  --web.enable-lifecycle
EOH
        destination = "local/start.sh"
        change_mode = "noop"
      }

      config {
        image      = "prom/prometheus:v3.10.0"
        entrypoint = ["/bin/sh", "/local/start.sh"]
        labels {
          group = "prometheus"
        }
        ports = ["prometheus"]
        dns_search_domains = ["home.andvari.net"]
      }
      volume_mount {
        volume = "monitoring"
        destination = "/data"
      }
      volume_mount {
        volume = "gitrepo"
        destination = "/config"
      }
      resources {
        cpu    = 200
        memory = 512
     }
    }

    network {
      port "prometheus" {
        static = "9090"
      }
    }

  }
}
