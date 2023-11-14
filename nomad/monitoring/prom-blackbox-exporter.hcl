job "prom-blackbox-exporter" {
  datacenters = ["home"]
  group "prom-blackbox-exporter_servers" {
    task "prom-blackbox-exporter_server" {
      service {
	      name = "prom-blackbox-exporter"
	      port = "prom-blackbox-exporter"
      }
      driver = "docker" 
      config {
        volumes = [
          "/things/homelab/monitoring:/config"
        ]
        image = "prom/blackbox-exporter"
        args = ["--config.file=/config/prom-blackbox-exporter.yml"]
        labels {
          group = "prom-blackbox-exporter"
        }
        ports = ["prom-blackbox-exporter"]
        dns_search_domains = ["home.andvari.net"]
      }
      resources {
        cpu = 1000
        memory = 1000
     }
    }

    network {
      port "prom-blackbox-exporter" {
        static = "9115"
      }
    }

  }
}
