job "newt" {
  datacenters = ["home"]
  group "newt_servers" {
    count = 1
    constraint {
      distinct_hosts = true
    }
    task "newt" {
      service {
        name = "newt"
        port = "metrics"
      }
      driver = "docker"
      config {
        image = "fosrl/newt:1.10.4"
        labels {
          group = "newt"
        }
        ports = ["metrics"]
      }
      template {
        data = <<EOH
{{- with nomadVar "nomad/jobs/newt" -}}
PANGOLIN_ENDPOINT={{ .endpoint }}
NEWT_ID={{ .id }}
NEWT_SECRET={{ .secret }}
{{- end -}}
EOH
        destination = "secrets/newt.txt"
        env = true
      }
      env {
        TZ                              = "Europe/Dublin"
        NEWT_METRICS_PROMETHEUS_ENABLED = "true"
        NEWT_ADMIN_ADDR                 = "0.0.0.0:2112"
      }
    }

    network {
      port "metrics" {
        static = "2112"
      }
    }
  }
}
