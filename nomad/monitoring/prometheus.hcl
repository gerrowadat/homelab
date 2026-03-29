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

      # Render the complete Prometheus config by reading prometheus.yml from
      # the gitrepo and appending Grafana Cloud remote_read credentials.
      #
      # Using {{ file }} causes Nomad to watch /config/monitoring/prometheus.yml
      # for changes. When the webhook pulls new code, Nomad detects the change,
      # re-renders this template, and sends SIGHUP to Prometheus — triggering a
      # graceful reload automatically, with no container restart needed.
      # Credential rotations (Nomad var changes) also trigger a graceful reload.
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
        change_mode = "signal"
        change_signal = "SIGHUP"
      }

      config {
        image  = "prom/prometheus:v3.10.0"
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
