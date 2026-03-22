job "grafana-alloy" {
  datacenters = ["home"]

  group "grafana_alloy" {

    task "alloy" {
      driver = "docker"

      # Credentials for Grafana Cloud metrics federation.
      # Create the Nomad variable at path nomad/jobs/grafana-alloy with keys:
      #   grafana_metrics_host  — hostname only, e.g. prometheus-prod-01-prod-us-east-0.grafana.net
      #   grafana_stack_id      — numeric stack ID (used as basic auth username)
      #   grafana_api_key       — Grafana Cloud API token (used as basic auth password)
      template {
        data = <<EOH
GRAFANA_METRICS_HOST="{{ with nomadVar "nomad/jobs/grafana-alloy" }}{{ .grafana_metrics_host }}{{ end }}"
GRAFANA_STACK_ID="{{ with nomadVar "nomad/jobs/grafana-alloy" }}{{ .grafana_stack_id }}{{ end }}"
GRAFANA_API_KEY="{{ with nomadVar "nomad/jobs/grafana-alloy" }}{{ .grafana_api_key }}{{ end }}"
EOH
        destination = "secrets/env"
        env         = true
      }

      # Alloy pipeline: federate probe_* metrics from Grafana Cloud SM, forward to local Prometheus.
      template {
        data = <<EOH
prometheus.scrape "grafana_cloud_sm" {
  targets = [{
    __address__ = env("GRAFANA_METRICS_HOST"),
  }]

  scheme       = "https"
  metrics_path = "/api/prom/federate"

  // Fetch all probe_* metrics from Grafana Cloud SM.
  // The source label is added via relabel below rather than filtered here,
  // so this works regardless of how checks were originally created.
  params = {
    "match[]" = ["{__name__=~\"probe_.*\"}"],
  }

  basic_auth {
    username = env("GRAFANA_STACK_ID")
    password = env("GRAFANA_API_KEY")
  }

  scrape_interval = "60s"
  scrape_timeout  = "30s"

  forward_to = [prometheus.relabel.add_source.receiver]
}

// Stamp source="grafana-sm" on every metric so Prometheus alert rules can
// distinguish these from local blackbox-exporter probe_* metrics.
prometheus.relabel "add_source" {
  rule {
    target_label = "source"
    replacement  = "grafana-sm"
  }

  forward_to = [prometheus.remote_write.local_prometheus.receiver]
}

prometheus.remote_write "local_prometheus" {
  endpoint {
    url = "http://prometheus.service.home.consul:9090/api/v1/write"
  }
}
EOH
        destination = "local/alloy.alloy"
      }

      config {
        image = "grafana/alloy:v1.7.1"
        args = [
          "run",
          "--server.http.listen-addr=0.0.0.0:${NOMAD_PORT_http}",
          "/local/alloy.alloy",
        ]
        ports = ["http"]
      }

      service {
        name = "grafana-alloy"
        port = "http"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    network {
      port "http" {}
    }
  }
}
