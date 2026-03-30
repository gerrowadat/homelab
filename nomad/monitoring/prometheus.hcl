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
      # Written to /local/remote_read.yml; change_mode=signal sends SIGHUP to
      # the supervisor script (prometheus_watch.sh, PID 1) on credential
      # rotation, which re-concatenates and reloads prometheus.
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
        change_mode = "signal"
        change_signal = "SIGHUP"
      }

      # prometheus_watch.sh (from gitrepo) is the entrypoint. It:
      #   1. Concatenates prometheus.yml + remote_read.yml -> /local/prometheus.yml
      #   2. Starts prometheus as a background process
      #   3. On SIGHUP: re-concatenates and reloads (handles credential rotation)
      #   4. Polls prometheus.yml every 10s: re-concatenates and reloads on change
      #      (handles pushes to main picked up by the homelab-webhook /-/reload)
      # Rule files use a glob (/config/monitoring/*_rules.yml) so new rule
      # files are picked up by /-/reload without touching prometheus.yml.
      config {
        image      = "prom/prometheus:v3.10.0"
        entrypoint = ["/bin/sh", "/config/nomad/monitoring/prometheus_watch.sh"]
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
