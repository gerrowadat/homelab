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

      config {
        image = "prom/prometheus:v2.43.0"
        args = ["--config.file=/config/monitoring/prometheus.yml",
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
      volume_mount {
        volume = "gitrepo"
        destination = "/config"
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
