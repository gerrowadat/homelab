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
      # Combined with the gitrepo prometheus.yml into /local/prometheus.yml at
      # task startup. change_mode=restart means credential rotation restarts the
      # task (acceptable — credentials change rarely).
      # Rule files use a glob (/config/monitoring/*_rules.yml) so new rule files
      # and alert rule changes are picked up by /-/reload (via the webhook) without
      # a redeploy. Scrape config changes in prometheus.yml require a redeploy.
      template {
        data = <<EOH
{{ file "/config/monitoring/prometheus.yml" }}
remote_read:
  - url: "https://{{ with nomadVar "nomad/jobs/prometheus" }}{{ .grafana_metrics_host }}{{ end }}/api/prom/api/v1/read"
    basic_auth:
      username: "{{ with nomadVar "nomad/jobs/prometheus" }}{{ .grafana_stack_id }}{{ end }}"
      password: "{{ with nomadVar "nomad/jobs/prometheus" }}{{ .grafana_metrics_read_token }}{{ end }}"
    read_recent: true
EOH
        destination = "local/prometheus.yml"
        change_mode = "restart"
      }

      config {
        image  = "prom/prometheus:v3.11.0"
        args   = [
          "--config.file=/local/prometheus.yml",
          "--storage.tsdb.path=/data/prometheus/prom-tsdb/",
          "--web.external-url=http://prometheus.service.home.consul:9090/",
          "--web.enable-lifecycle",
        ]
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
