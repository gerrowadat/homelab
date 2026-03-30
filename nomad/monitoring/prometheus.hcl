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
      # Written to /alloc/remote_read.yml (shared allocation dir) so the
      # prometheus_config_watcher sidecar can read it when re-concatenating.
      # change_mode=noop: the sidecar detects the file change and reloads.
      template {
        data = <<EOH
remote_read:
  - url: "https://{{ with nomadVar "nomad/jobs/prometheus" }}{{ .grafana_metrics_host }}{{ end }}/api/prom/api/v1/read"
    basic_auth:
      username: "{{ with nomadVar "nomad/jobs/prometheus" }}{{ .grafana_stack_id }}{{ end }}"
      password: "{{ with nomadVar "nomad/jobs/prometheus" }}{{ .grafana_metrics_read_token }}{{ end }}"
    read_recent: true
EOH
        destination = "alloc/remote_read.yml"
        change_mode = "noop"
      }

      # Startup script: concatenate the gitrepo prometheus.yml with the
      # remote_read section into /alloc/prometheus.yml (shared allocation dir),
      # then exec Prometheus against the combined file.
      # The prometheus_config_watcher sidecar re-concatenates and reloads
      # whenever either source file changes, enabling live /-/reload for all
      # config changes including new scrape jobs.
      # Rule files use a glob (/config/monitoring/*_rules.yml) so new rule
      # files are also picked up by /-/reload without touching prometheus.yml.
      template {
        data = <<EOH
#!/bin/sh
set -e
cat /config/monitoring/prometheus.yml /alloc/remote_read.yml > /alloc/prometheus.yml
exec /bin/prometheus \
  --config.file=/alloc/prometheus.yml \
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

    # Sidecar: watches prometheus.yml (gitrepo) and remote_read.yml for changes,
    # re-concatenates into /alloc/prometheus.yml, and calls /-/reload.
    # This allows any config change to be picked up via /-/reload (triggered
    # by the homelab-webhook on push to main) without a nomad job run.
    # Tasks share the allocation directory (/alloc/), so both tasks see the
    # same /alloc/prometheus.yml and /alloc/remote_read.yml.
    # Tasks share the group network namespace, so localhost:9090 reaches prometheus.
    task "prometheus_config_watcher" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image      = "alpine:3"
        entrypoint = ["/bin/sh", "/config/nomad/monitoring/prometheus_watch.sh"]
      }

      volume_mount {
        volume      = "gitrepo"
        destination = "/config"
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    network {
      port "prometheus" {
        static = "9090"
      }
    }

  }
}
