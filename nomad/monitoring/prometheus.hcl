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

    task "prometheus_server" {
      service {
	      name = "prometheus"
	      port = "prometheus"
      }
      driver = "docker" 

      template {
        data = "{{ with nomadVar \"nomad/jobs/prometheus\" }}{{ .prometheus_yml }}{{ end }}"
        destination = "local/prometheus.yml"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 744
      }

      config {
        volumes = [
          "/things/homelab/monitoring:/config",
          //"/things/docker/prometheus:/data"
        ]
        image = "prom/prometheus:v2.43.0"
        args = ["--config.file=/config/prometheus.yml",
                "--storage.tsdb.path=/data/prometheus/prom-tsdb/",
                # URL to pass to alertmanager etc.
                "--web.external-url=http://prometheus.home.nomad.andvari.net:9090/",
                # Enable reload via web
                "--web.enable-lifecycle"]
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
      resources {
        cpu = 2000
        memory = 2000
     }
    }

    network {
      port "prometheus" {
        static = "9090"
      }
    }

  }
}
